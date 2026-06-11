# Rules As Data

Policy rules live in records, not code. Policy_Rule_Version__c is immutable after referenced by any Decision_Event__c. Versioning via `Supersedes__c` — new version auto-expires prior. Only ONE active version per `Rule_Code__c`. No hardcoded thresholds in Apex. Analysts maintain rules through UI quick actions — no deployment required.

**Enforcement:** `PolicyRuleVersionHandler` + `PolicyRuleVersionTrigger` (auto-version, supersession, immutability-after-reference, no-delete). Verified by `PolicyRuleVersionHandlerTest` (7 tests).

**Source:** ADR-4, ADR-12, B5.
