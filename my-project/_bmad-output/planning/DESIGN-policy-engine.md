# DESIGN: Policy Rule Engine

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

---

## Overview

The policy rule engine is the kernel of Mortagate. It evaluates loan applications against versioned business rules and produces an immutable audit trail. Three layers, zero side effects in the evaluator, bulk-safe by construction.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    POLICY RULE ENGINE                        │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────┐ │
│  │ FactAssembler    │→ │ PolicyRule       │→ │ Decision  │ │
│  │ Service          │  │ Evaluator        │  │ Commit    │ │
│  │                  │  │                  │  │ Service   │ │
│  │ • Queries DB     │  │ • Pure function  │  │ • Writes  │ │
│  │ • Builds context │  │ • Zero DB access │  │ • Creates │ │
│  │ • Returns VO     │  │ • Returns result │  │   DE__c   │ │
│  └──────────────────┘  └──────────────────┘  └───────────┘ │
│         ↑                      ↑                    ↑       │
│    Extracted_Facts__c    Policy_Rule_Version__c   Decision_ │
│    + Evidence__c         (governing set)         Event__c   │
└─────────────────────────────────────────────────────────────┘
```

---

## Value Objects (Apex)

### PolicyEvaluationContext
```apex
public class PolicyEvaluationContext {
    public final Id loanApplicationId;
    public final Map<String, Object> applicantFacts;  // field API name → value
    public final Map<String, String> evidenceStatus;  // docType → VERIFIED|PENDING|MISSING
    public final Id ruleVersionSetId;                 // null = use current active set
    public final Datetime evaluationTimestamp;
    
    // Constructor enforces all required fields
    public PolicyEvaluationContext(Id loanAppId, Map<String, Object> facts,
                                   Map<String, String> evidence) {
        this.loanApplicationId = loanAppId;
        this.applicantFacts = facts.clone();  // defensive copy
        this.evidenceStatus = evidence.clone();
        this.evaluationTimestamp = Datetime.now();
    }
}
```

### EvaluationResult
```apex
public class EvaluationResult {
    public final String verdict;           // APPROVED, APPROVED_WITH_CONDITIONS, PENDING_REVIEW, HARD_DECLINED
    public final List<RuleOutcome> triggeredRules;
    public final Integer totalRulesEvaluated;
    public final Integer hardDeclineCount;
    public final Integer softDeclineCount;
    public final Integer warningCount;
    public final Datetime evaluationTimestamp;
}
```

### RuleOutcome
```apex
public class RuleOutcome {
    public final Id ruleVersionId;
    public final String ruleCode;
    public final Integer versionNumber;
    public final String outcome;           // PASS, FAIL, INDETERMINATE
    public final String severity;          // HARD_DECLINE, SOFT_DECLINE, WARNING, ADVISORY
    public final String explanation;       // From Rule_Explanation__c — human-readable
    public final Object factValue;         // The actual value tested
    public final Object threshold;         // The threshold it was tested against
}
```

---

## Evaluation Algorithm

```
INPUT:  PolicyEvaluationContext
OUTPUT: EvaluationResult

1. Load governing rules:
   SELECT Id, Rule_Code__c, Version_Number__c, Operator__c, 
          Threshold_Value__c, Threshold_High__c, Allowed_Values__c,
          Fact_Field__c, Severity__c, Rule_Explanation__c,
          Rule_Category__c, Override_Permitted__c
   FROM Policy_Rule_Version__c
   WHERE Is_Active__c = true
     AND Effective_Date__c <= :ctx.evaluationTimestamp
     AND (Expiration_Date__c = null OR Expiration_Date__c > :ctx.evaluationTimestamp)
   ORDER BY Severity__c DESC, Rule_Code__c ASC

2. For each rule:
   a. Get fact_value = ctx.applicantFacts.get(rule.Fact_Field__c)
   b. If null → INDETERMINATE (fact not yet available)
   c. Evaluate: compare fact_value against operator + threshold
   d. Record outcome with full context

3. Determine verdict:
   - Any HARD_DECLINE failure → HARD_DECLINED
   - Any SOFT_DECLINE failure → PENDING_REVIEW  
   - Any WARNING failure → APPROVED_WITH_CONDITIONS
   - All pass → APPROVED

4. Return EvaluationResult (no writes, no side effects)
```

### Operator Implementation
```apex
private static Boolean evaluateOperator(Object factValue, String operator,
                                         Decimal threshold, Decimal thresholdHigh,
                                         String allowedValuesJson) {
    switch on operator {
        when 'GT'  { return toDecimal(factValue) > threshold; }
        when 'GTE' { return toDecimal(factValue) >= threshold; }
        when 'LT'  { return toDecimal(factValue) < threshold; }
        when 'LTE' { return toDecimal(factValue) <= threshold; }
        when 'EQ'  { return toDecimal(factValue) == threshold; }
        when 'BETWEEN' { 
            Decimal v = toDecimal(factValue);
            return v >= threshold && v <= thresholdHigh; 
        }
        when 'IN_LIST' {
            List<String> allowed = (List<String>) JSON.deserialize(allowedValuesJson, List<String>.class);
            return allowed.contains(String.valueOf(factValue));
        }
        when 'NOT_IN_LIST' {
            List<String> blocked = (List<String>) JSON.deserialize(allowedValuesJson, List<String>.class);
            return !blocked.contains(String.valueOf(factValue));
        }
        when else { throw new PolicyEngineException('Unknown operator: ' + operator); }
    }
}
```

---

## Versioning Rules

### Compound Key
`(Rule_Code__c, Version_Number__c)` — globally unique.

### Resolution at Decision Time
Highest Version_Number__c per Rule_Code__c within the effective date window.

### Supersession Flow
1. Analyst clicks "Create New Version" quick action on existing rule
2. New record pre-populated from current version
3. Analyst modifies threshold/criteria, sets new Effective_Date__c
4. On save:
   - Trigger auto-increments Version_Number__c
   - Trigger sets Expiration_Date__c on prior version = new Effective_Date__c
   - Trigger sets Supersedes__c lookup on new version → prior version
5. No code deployment. No sandbox refresh.

### Immutability After Reference
Once a Policy_Rule_Version__c record is referenced by any Decision_Event__c, it becomes immutable. A before-update trigger checks for existing Decision_Event__c references and throws if any exist.

---

## Bulk Safety Contract

| Operation | Count for N applications |
|-----------|------------------------|
| Load governing rules | 1 SOQL |
| Load all facts | 1 SOQL |
| Load evidence status | 1 SOQL |
| Evaluate (in-memory) | 0 SOQL, 0 DML |
| Insert Decision_Event__c records | 1 DML |
| **Total** | **3 SOQL + 1 DML** |

Scales linearly. Tested at 200+ records per Salesforce Flow quality gates.

---

## Non-Developer Rule Maintenance

### Adding a New Rule
1. Navigate to Policy Rule Versions tab
2. Click "New Rule Version"
3. Fill in guided form (all operators and categories are picklists)
4. Set Effective_Date__c
5. Save → system assigns Version_Number__c = 1

### Modifying an Existing Rule
1. Open existing rule record
2. Click "Create New Version" quick action
3. Modify threshold or criteria
4. Set new Effective_Date__c
5. Save → prior version auto-expires

### What Non-Developers Cannot Do
- Delete any rule version (blocked by trigger)
- Modify a referenced rule version (blocked by trigger)
- Create invalid operator/fact combinations (blocked by validation rules)
- Set overlapping effective dates for the same Rule_Code__c (blocked by trigger)
