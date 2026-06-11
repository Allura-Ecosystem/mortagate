---
name: apex-quality
description: "Apex quality, bulk-safety, and refactor discipline. No DML/SOQL/Get Records in loops. Thin triggers, service classes, 200+ record bulk tests. Load when writing, reviewing, or refactoring Apex in the Mortgate project."
---

# apex-quality — Apex Quality & Bulk-Safety for Mortgate

This skill enforces the **Apex Quality Gates** for the **Mortgage Approval Engine** project. Use it whenever writing, reviewing, or refactoring Apex code.

> **AI-Assisted Documentation**
> Portions of this skill were drafted with AI assistance.

---

## When to Use This Skill

Load this skill whenever:

- Writing Apex (trigger, class, batch, queueable, scheduled)
- Reviewing a PR with Apex changes
- Diagnosing governor limit errors
- Designing a service class
- Refactoring fat triggers
- Running Apex tests

---

## Non-Negotiable Quality Gates

### Bulk Safety (Hard Rules)

- ❌ **No DML inside loops** — collect first, DML once
- ❌ **No SOQL inside loops** — query first, iterate over the result
- ❌ **No `Get Records` (Flow) inside loops** — use collection variables
- ❌ **No looping on `$Record` collection** — use collection variables
- ✅ **Collect outside loop, process inside, DML once after**

### Fault Paths (Flows)

- Every DML / email / callout element **must** have a fault connector
- Route faults to a dedicated fault handler — never loop back
- On fault: log to a custom object or Platform Event, show user-friendly message, exit cleanly

### Append-Only Audit

- `Decision_Event__c` UPDATE and DELETE are forbidden
- Enforced by Apex trigger, not by convention

### Test Coverage

- All Apex must have unit tests
- 200+ record bulk tests for record-triggered code paths
- `sf apex run test --code-coverage --result-format human` must pass

---

## Trigger Pattern (Thin Delegate)

```apex
trigger ApplicationTrigger on Application__c (before insert, before update, after insert, after update) {
  if (Trigger.isBefore) {
    if (Trigger.isInsert) {
      ApplicationService.onBeforeInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
      ApplicationService.onBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
  }
  if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      ApplicationService.onAfterInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
      ApplicationService.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
  }
}
```

**Trigger rules:**

- Triggers contain ZERO business logic
- They are 1-2 line delegates to a service class
- Logic in service classes is unit-testable without trigger context
- One trigger per SObject

---

## Service Class Pattern

```apex
public with sharing class ApplicationService {
  public static void onBeforeInsert(List<Application__c> newRecords) {
    setApplicationNumber(newRecords);
    validateLoanPurpose(newRecords);
  }

  public static void onAfterInsert(List<Application__c> newRecords) {
    List<Decision_Event__c> events = new List<Decision_Event__c>();
    for (Application__c app : newRecords) {
      events.add(new Decision_Event__c(
        Application__c = app.Id,
        Event_Type__c = 'Application_Submitted',
        Decision__c = 'Pending'
      ));
    }
    insert events; // DML outside the loop
  }

  private static void setApplicationNumber(List<Application__c> records) {
    for (Application__c app : records) {
      if (String.isBlank(app.Application_Number__c)) {
        app.Application_Number__c = generateAppNumber();
      }
    }
  }

  private static String generateAppNumber() {
    // Use a custom setting or counter to ensure uniqueness
    return 'APP-' + String.valueOf(System.now().getTime()).substring(0, 10);
  }

  private static void validateLoanPurpose(List<Application__c> records) {
    Set<String> validPurposes = new Set<String>{ 'Purchase', 'Refinance', 'CashOut_Refinance' };
    for (Application__c app : records) {
      if (!validPurposes.contains(app.Loan_Purpose__c)) {
        app.addError('Invalid loan purpose: ' + app.Loan_Purpose__c);
      }
    }
  }
}
```

---

## SOQL Best Practices

### Avoid SOQL in Loops (CRITICAL)

```apex
// ❌ BAD
for (Application__c app : Trigger.new) {
  List<Policy_Rule__c> rules = [SELECT Id, Name FROM Policy_Rule__c WHERE Active__c = true];
  // ... process rules
}

// ✅ GOOD
List<Policy_Rule__c> activeRules = [SELECT Id, Name FROM Policy_Rule__c WHERE Active__c = true];
for (Application__c app : Trigger.new) {
  // ... process pre-fetched rules
}
```

### Use Maps for Lookups

```apex
// ❌ BAD
for (Application__c app : Trigger.new) {
  Borrower__c borrower = [SELECT Id, Name FROM Borrower__c WHERE Id = :app.Borrower__c];
  // ...
}

// ✅ GOOD
Set<Id> borrowerIds = new Map<Id, Application__c>(Trigger.new).keySet();
Map<Id, Borrower__c> borrowers = new Map<Id, Borrower__c>(
  [SELECT Id, Name FROM Borrower__c WHERE Id IN :borrowerIds]
);
for (Application__c app : Trigger.new) {
  Borrower__c borrower = borrowers.get(app.Borrower__c);
  // ...
}
```

### Selective Queries

```apex
// ✅ Indexed field
[SELECT Id FROM Application__c WHERE CreatedDate = LAST_N_DAYS:30 AND Status__c = 'Active'];
// ❌ Non-selective, full table scan
[SELECT Id FROM Application__c WHERE Annual_Income__c > 50000];
```

---

## Test Pattern (200+ Records)

```apex
@isTest
private class ApplicationServiceTest {
  @testSetup
  static void setup() {
    List<Application__c> apps = new List<Application__c>();
    for (Integer i = 0; i < 250; i++) {
      apps.add(new Application__c(
        Loan_Purpose__c = 'Purchase',
        Annual_Income__c = 75000 + i,
        Status__c = 'Submitted'
      ));
    }
    insert apps;
  }

  @isTest
  static void testBeforeInsert_setsApplicationNumber() {
    List<Application__c> apps = [SELECT Id, Application_Number__c FROM Application__c];
    System.assertNotEquals(null, apps[0].Application_Number__c, 'Number must be set');
    System.assert(apps[0].Application_Number__c.startsWith('APP-'), 'Format must be APP-XXXX');
  }

  @isTest
  static void testAfterInsert_createsDecisionEvent() {
    List<Decision_Event__c> events = [SELECT Id, Event_Type__c FROM Decision_Event__c];
    System.assertEquals(250, events.size(), 'One event per application');
    for (Decision_Event__c evt : events) {
      System.assertEquals('Application_Submitted', evt.Event_Type__c);
    }
  }

  @isTest
  static void testInvalidLoanPurpose_throwsError() {
    List<Application__c> bad = new List<Application__c>{
      new Application__c(Loan_Purpose__c = 'InvalidValue')
    };
    try {
      insert bad;
      System.assert(false, 'Expected an error');
    } catch (DmlException e) {
      System.assert(e.getMessage().contains('Invalid loan purpose'), 'Expected validation error');
    }
  }
}
```

---

## Async Patterns

### Queueable (for chains or fast async)

```apex
public class PolicyEvaluationQueueable implements Queueable, Database.AllowsCallouts {
  private Id applicationId;

  public PolicyEvaluationQueueable(Id applicationId) {
    this.applicationId = applicationId;
  }

  public void execute(QueueableContext context) {
    PolicyEngine.evaluate(applicationId);
  }
}
```

### Batch (for >50k records)

```apex
public class PolicyEvaluationBatch implements Database.Batchable<SObject> {
  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator([
      SELECT Id FROM Application__c WHERE Status__c = 'Submitted'
    ]);
  }

  public void execute(Database.BatchableContext context, List<Application__c> scope) {
    PolicyEngine.evaluateBatch(scope);
  }

  public void finish(Database.BatchableContext context) {}
}
```

---

## Decision Event Pattern (Append-Only)

```apex
public with sharing class DecisionEventService {
  public static Decision_Event__c create(
    Id applicationId,
    String eventType,
    String decision,
    String reasonCode,
    String notes
  ) {
    return new Decision_Event__c(
      Application__c = applicationId,
      Event_Type__c = eventType,
      Decision__c = decision,
      Reason_Code__c = reasonCode,
      Notes__c = notes
    );
  }

  public static void insertBatch(List<Decision_Event__c> events) {
    if (!events.isEmpty()) {
      insert events; // append-only
    }
  }
}
```

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Apex class | PascalCase | `ApplicationService` |
| Test class | `<Class>Test` | `ApplicationServiceTest` |
| Trigger | `<SObject>Trigger` | `ApplicationTrigger` |
| Constant | SCREAMING_SNAKE | `MAX_LOAN_AMOUNT` |
| SObject API | PascalCase__c | `Application__c` |
| Field API | PascalCase__c | `Annual_Income__c` |

---

## Anti-Patterns

- ❌ Fat triggers with logic
- ❌ SOQL/DML inside loops
- ❌ Hard-coded IDs
- ❌ `with sharing` missing
- ❌ `try/catch` swallowing exceptions
- ❌ `System.debug` in production (use a logging framework)
- ❌ Apex sharing violations
- ❌ Re-triggering via update-after-update

---

## Code Review Checklist

When reviewing Apex, check:

- [ ] No DML inside loops
- [ ] No SOQL inside loops
- [ ] Trigger is a thin delegate
- [ ] Logic in service class
- [ ] 200+ record test
- [ ] `with sharing` declared
- [ ] Field-level security checked (CRUD/FLS)
- [ ] Error handling present
- [ ] No hard-coded IDs
- [ ] Append-only audit enforced for `Decision_Event__c`

---

## Output to Brain

```javascript
allura-brain_memory_add({
  group_id: "allura-mortgage",
  user_id: "fowler-refactor-gate-mortgage",
  content: "APEX_REVIEW: {class}, {verdict: pass|refactor|veto}, {issues}",
  metadata: { source: "apex-review", agent_id: "fowler-refactor-gate-mortgate", event_type: "APEX_REVIEW" }
})
```
