# Adverse Action Validator

**Trigger:** After any change to `AdverseActionService`, `AdverseActionNotice.page`, `AdverseActionNoticeController`, or `Adverse_Action_Config__mdt`.

---

## Checks

- [ ] Reasons come from `Rule_Explanation__c` (specific, not boilerplate)
- [ ] HARD_DECLINE reasons ranked first
- [ ] Capped at 4 reasons (Reason_Limit__c), deduped, blanks skipped
- [ ] ECOA anti-discrimination text present (from config)
- [ ] `[AGENCY]` token resolved to oversight agency name + address
- [ ] Creditor name + address present (from config)
- [ ] Statement of action taken present
- [ ] FCRA score block: present when FICO_Score__c exists, absent when not
- [ ] CRA identity marked as pending (honest about P3 scope)
- [ ] Forbidden phrasing not emitted ("qualifying score", "internal standards")
- [ ] `AdverseActionServiceTest` (13 tests) passes
- [ ] `AdverseActionNoticeControllerTest` (5 tests) passes
- [ ] `outcomeView` Jest tests for viewnotice pass
- [ ] No `escape="false"` on the VF page
- [ ] No `apex:form` on the VF page (read-only artifact)

**Source:** ADR-10, DESIGN-adverse-action.md, 12 CFR 1002.9, 15 U.S.C. 1681m.
