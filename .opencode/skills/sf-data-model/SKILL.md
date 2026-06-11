---
name: sf-data-model
description: "Salesforce SObject data model discipline. Schema design, field types, referential integrity, DATA-DICTIONARY updates, and append-only audit patterns. Load when designing or reviewing SObject metadata in the Mortgate project."
---

# sf-data-model — Salesforce Data Architect Skill

This skill is the gateway to all Salesforce SObject design and review for the **Mortgage Approval Engine** project.

> **AI-Assisted Documentation**
> Portions of this skill were drafted with AI assistance.

---

## When to Use This Skill

Load this skill whenever:

- Designing a new SObject
- Reviewing SObject metadata for drift
- Adding/changing fields
- Updating `DATA-DICTIONARY.md`
- Deciding between MD, Picklist, Lookup, or Master-Detail relationships
- Auditing referential integrity
- Designing the append-only audit pattern (e.g., `Decision_Event__c`)

---

## Core Mortgate SObjects

| SObject | Purpose | Criticality |
|---|---|---|
| `Application__c` | Borrower mortgage application (the central record) | Core |
| `Decision_Event__c` | Immutable decision audit log | **Critical — append-only** |
| `Extracted_Facts__c` | Typed per-category facts (income, assets, employment) | Core |
| `Policy_Rule__c` | Rules-as-data for the decision engine | Core |
| `Document__c` | Borrower uploaded docs (W-2, paystub, bank statement) | Standard |
| `Property__c` | Subject property information | Standard |
| `Borrower__c` | Borrower profile (linked to Contact) | Standard |

---

## SObject Skeleton

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
  <actionOverrides>...</actionOverrides>
  <allowInChatterGroups>false</allowInChatterGroups>
  <compactLayoutAssignment>SYSTEM</compactLayoutAssignment>
  <deploymentStatus>Deployed</deploymentStatus>
  <description>{description}</description>
  <enableActivities>true</enableActivities>
  <enableBulkApi>true</enableBulkApi>
  <enableFeeds>false</enableFeeds>
  <enableHistory>true</enableHistory>
  <enableReports>true</enableReports>
  <enableSearch>true</enableSearch>
  <enableSharing>true</enableSharing>
  <enableStreamingApi>true</enableStreamingApi>

  <fields>
    <fullName>{API_Name__c}</fullName>
    <description>{desc}</description>
    <inlineHelpText>{help}</inlineHelpText>
    <label>{Label}</label>
    <length>255</length>
    <required>{true|false}</required>
    <type>{Text|Picklist|Number|Currency|Date|...}</type>
  </fields>

  <recordTypes>...</recordTypes>
  <validationRules>...</validationRules>
  <webLinks>...</webLinks>
</CustomObject>
```

---

## Append-Only Audit Pattern (Decision_Event__c)

`Decision_Event__c` is the **immutable decision log**. Enforce immutability at the platform level:

```xml
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
  <allowInChatterGroups>false</allowInChatterGroups>
  <deploymentStatus>Deployed</deploymentStatus>
  <description>Append-only decision audit log. UPDATE/DELETE forbidden.</description>

  <fields>
    <fullName>Application__c</fullName>
    <referenceTo>Application__c</referenceTo>
    <relationshipLabel>Decision Events</relationshipLabel>
    <relationshipName>Decision_Events</relationshipName>
    <type>Lookup</type>
  </fields>
  <fields>
    <fullName>Event_Type__c</fullName>
    <label>Event Type</label>
    <type>Picklist</type>
    <valueSet>
      <restricted>true</restricted>
      <valueSetDefinition>
        <sorted>false</sorted>
        <value><fullName>Application_Submitted</fullName></value>
        <value><fullName>Policy_Evaluated</fullName></value>
        <value><fullName>Decision_Rendered</fullName></value>
        <value><fullName>Adverse_Action_Issued</fullName></value>
      </valueSetDefinition>
    </valueSet>
  </fields>
  <fields>
    <fullName>Decision__c</fullName>
    <label>Decision</label>
    <type>Picklist</type>
    <valueSet>
      <restricted>true</restricted>
      <valueSetDefinition>
        <sorted>false</sorted>
        <value><fullName>Approved</fullName></value>
        <value><fullName>Declined</fullName></value>
        <value><fullName>Refer</fullName></value>
        <value><fullName>Pending</fullName></value>
      </valueSetDefinition>
    </valueSet>
  </fields>
  <fields>
    <fullName>Reason_Code__c</fullName>
    <label>Reason Code</label>
    <length>32</length>
    <type>Text</type>
  </fields>
  <fields>
    <fullName>Notes__c</fullName>
    <label>Notes</label>
    <length>32768</length>
    <type>LongTextArea</type>
  </fields>
</CustomObject>
```

**Immutability enforcement (Apex trigger):**

```apex
trigger DecisionEventTrigger on Decision_Event__c (before update, before delete, after undelete) {
  for (Decision_Event__c evt : Trigger.new) {
    if (Trigger.isUpdate || Trigger.isDelete) {
      evt.addError('Decision_Event__c is append-only. UPDATE and DELETE are forbidden.');
    }
  }
  if (Trigger.isUndelete) {
    Trigger.new[0].addError('Decision_Event__c is append-only. Restore is not allowed.');
  }
}
```

---

## Field Type Selection

| Need | Type | Example |
|---|---|---|
| Borrower name | Text(80) | `Borrower_Name__c` |
| Annual income | Currency(16,2) | `Annual_Income__c` |
| Credit score | Number(3,0) | `Credit_Score__c` |
| Loan purpose | Picklist | `Loan_Purpose__c` |
| Application date | Date | `Application_Date__c` |
| Submitted timestamp | DateTime | `Submitted_At__c` |
| Free-text notes | LongTextArea(32768) | `Notes__c` |
| Foreign key | Lookup or MD | `Application__c` |
| Auto-number | AutoNumber | `Application_Number__c` |
| Decision payload | LongTextArea(JSON) | `Decision_Payload__c` |

**Anti-patterns:**

- ❌ Storing currency as Number (use Currency)
- ❌ Storing JSON as Text (use LongTextArea or a structured child SObject)
- ❌ Using LongTextArea for short labels (use Text)
- ❌ EAV pattern (use typed fields per fact category)

---

## DATA-DICTIONARY.md Update Pattern

When fields change, update `DATA-DICTIONARY.md` in the same PR:

```markdown
## Application__c

| Field | API Name | Type | Length | Required | Description | Notes |
|---|---|---|---|---|---|---|
| Annual Income | Annual_Income__c | Currency | (16, 2) | Yes | Self-reported annual income | Captured in Screen 3 |
| Loan Purpose | Loan_Purpose__c | Picklist | - | Yes | Purchase or Refinance | Values: Purchase, Refinance, CashOut_Refinance |
| Application Number | Application_Number__c | AutoNumber | 8 | - | System-generated ID | Format: APP-{0000000} |
| Application Date | Application_Date__c | Date | - | Yes | Date the application was created | Defaults to TODAY() |
```

---

## Relationship Cardinality

| Cardinality | Use | Example |
|---|---|---|
| One-to-Many (Lookup) | Loose coupling, optional | `Application__c` → many `Decision_Event__c` |
| One-to-Many (Master-Detail) | Tight coupling, ownership, rollups | `Application__c` (master) → many `Document__c` (detail) |
| Many-to-Many (Junction) | Both sides can have many | `Application__c` ↔ `Product__c` via `Application_Product__c` |
| Hierarchical | Self-lookup | `Account.ParentId` style |

---

## Bulkification Notes

- Triggers run on up to 200 records at a time
- Use `Trigger.new` and `Trigger.newMap` (not single-record semantics)
- Aggregate queries in AFTER triggers count against limits
- Consider Batch Apex for >50k records

---

## Validation Rules (sample)

```xml
<ValidationRule>
  <fullName>Annual_Income_Required</fullName>
  <active>true</active>
  <errorConditionFormula>ISBLANK(Annual_Income__c)</errorConditionFormula>
  <errorDisplayField>Annual_Income__c</errorDisplayField>
  <errorMessage>Annual income is required to evaluate policy.</errorMessage>
</ValidationRule>
```

---

## When in Doubt

1. **Existing pattern** — check the other Mortgate SObjects first
2. **Salesforce limits** — Text(255) for short strings, LongTextArea(32k) for JSON
3. **Append-only** — anything audit-related goes in `Decision_Event__c`
4. **Rules are data** — policy logic lives in `Policy_Rule__c`, not Apex
5. **Knuth owns schema** — Brooks owns the contract; Knuth owns the field

---

## Output to Brain

```javascript
allura-brain_memory_add({
  group_id: "allura-mortgage",
  user_id: "knuth-data-architect-mortgage",
  content: "SCHEMA_DECISION: {SObject}, {field}, {type}, {rationale}",
  metadata: { source: "schema-design", agent_id: "knuth-data-architect-mortgage", event_type: "SCHEMA_CHANGE" }
})
```
