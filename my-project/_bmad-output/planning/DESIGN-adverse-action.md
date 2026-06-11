# DESIGN: Adverse Action Notice (ECOA / Regulation B)

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

> [!WARNING]
> **Not legal advice.** This document records an engineering implementation of a
> regulated artifact based on the cited public regulatory text. It must be reviewed
> and signed off by qualified compliance counsel before any notice is delivered to a
> real applicant. Citations are provided so counsel can verify, not so engineers can
> self-certify.

---

## Why this exists

A mortgage system that declines an application incurs a legal obligation the decision
kernel alone does not satisfy: it must deliver a **notice of action taken** that gives
the applicant the **specific** reasons for the decision. This is the Equal Credit
Opportunity Act (ECOA, 15 U.S.C. 1691 et seq.) and its implementing **Regulation B,
12 CFR 1002.9**. The Fair Credit Reporting Act (FCRA, 15 U.S.C. 1681m) adds a separate
obligation when a consumer report was used.

The kernel already holds the raw material — every decline carries the failing rules
and their human explanations in the append-only `Decision_Event__c`. What was missing
was the compliant *composition* of that material into a notice. This feature closes
that gap with code only; no vendor or paid add-on is required to generate the notice.

---

## What the regulation requires (and where we implement it)

Source consulted: Cornell Law School's mirror of **12 CFR 1002.9**
(`https://www.law.cornell.edu/cfr/text/12/1002.9`), cross-checked against CFPB guidance.

| Requirement | Citation | Implementation |
|---|---|---|
| Statement of the action taken | 1002.9(a)(2)(i) | `Notice.actionStatement` |
| Name and address of the creditor | 1002.9(a)(2)(i) | `Notice.creditorName` / `creditorAddress` (config) |
| ECOA §701(a) anti-discrimination notice (substantially similar wording) | 1002.9(b)(1) | `Notice.ecoaNotice` (verbatim template in config) |
| Name and address of the federal agency that administers compliance | 1002.9(b)(1) | folded into `ecoaNotice` via the `[AGENCY]` token |
| **Specific** principal reasons for the action | 1002.9(b)(2) | `Notice.reasons`, sourced from each failing rule's `Rule_Explanation__c` |
| Timing: within 30 days of a completed application | 1002.9(a)(1) | `Notice.respondByDate = noticeDate + Notice_Window_Days__c` (informational) |

### The 1002.9(b)(2) trap

The Official Interpretation is explicit that a notice is **non-compliant** if its reasons
are not specific — phrases like *"failed to achieve a qualifying score on the creditor's
credit scoring system"* or *"did not meet our internal standards"* are insufficient. Our
reasons are never that boilerplate: they are the rules' own human-written explanations,
which describe the actual condition (e.g. *"Your debt-to-income ratio exceeds our
threshold of 43%."*). A test (`doesNotEmitForbiddenScoreOnlyPhrasing`) pins this.

### Number of reasons

Reg B mandates no specific count, but the Official Interpretation treats disclosing
**more than four** principal reasons as unhelpful. We cap at four (`Reason_Limit__c`,
configurable), and rank `HARD_DECLINE` rules first because those are what actually drove
the denial.

### FCRA credit-score disclosure (separate obligation)

When a consumer report is used, FCRA (15 U.S.C. 1681m) requires disclosing the score,
key factors, the consumer reporting agency, and the consumer's rights (free report within
60 days, right to dispute). The FCRA disclosure does **not** satisfy ECOA's specific-reason
requirement — both must appear. We render the score block when a `FICO_Score__c` is on
file, and we are **honest about scope**: until the P3 credit-bureau integration lands, the
consumer reporting agency identity is not captured, so the block discloses the score and
rights and names the CRA detail as *pending* rather than inventing a source.

---

## Architecture

Mirrors the policy-engine separation: a **pure** composition class with zero SOQL/DML
(unit-testable without an org, NFR-6) and a thin **controller** that does the I/O.

```
Decision_Event__c (append-only)            Adverse_Action_Config__mdt (config-as-data)
        │  Rule_Results_JSON__c (FAIL rows)        │  creditor / agency / ECOA template / caps
        │  Application__r.Borrower__r.Name         │
        │  Extracted_Facts__c.FICO_Score__c        │
        ▼                                          ▼
  AdverseActionNoticeController  ── maps values ──►  AdverseActionService.build(...)
        (with sharing, FLS/CRUD,                         (pure: verdict + failing rules
         bind var, USER_MODE, pure read)                  + score + config → Notice)
        │
        ▼
  AdverseActionNotice.page  (renderAs="pdf", Veridact-skinned, standard {!} escaping)
```

- **`AdverseActionService`** — pure. `build(verdict, failingRules, creditScore, config,
  applicantName, noticeDate) → Notice`. Determines adverse action (`HARD_DECLINED`),
  selects specific reasons (HARD first, deduped, capped), resolves the `[AGENCY]` token,
  builds the FCRA block. Tolerates a null config (degrades to blanks, never throws).
- **`AdverseActionNoticeController`** — `with sharing`, pure read. Validates `?id=`,
  enforces object + field-level access, fetches the event with a bind variable under
  `USER_MODE`, parses FAIL rows, looks up the latest verified `FICO_Score__c`, maps the
  `Default` CMDT into the service config.
- **`AdverseActionNotice.page`** — PDF letter, no `apex:form`, no `escape="false"`,
  because the artifact is delivered to the applicant.
- **`Adverse_Action_Config__mdt` (`Default`)** — config-as-data so compliance can update
  the creditor address, the oversight agency, or the verbatim notice without a code
  release. Ships with the CFPB as the oversight agency (1700 G Street NW, Washington, DC).

### Why config-as-data

The oversight agency and its address change over time, and the creditor identity differs
per deployment. Hard-coding any of that into Apex would force a release for a compliance
edit. The CMDT pattern (already used by `PreFlight_Assumption__mdt`) lets the legal owner
keep the disclosure current.

---

## Allura governance alignment

The notice is a *read* of the append-only `Decision_Event__c`; it creates no new
authoritative state and cannot mutate the event (no DML, no `apex:form`). It therefore
sits cleanly inside the same immutability invariant as the Decision Receipt — the notice
is a *rendering* of a committed decision, never a new decision. Delivery/promotion (who
sends it, and the record that it was sent) remains a human-in-the-loop step to be wired in
P1, consistent with the HITL-before-promotion invariant.

---

## What is built vs. what compliance still owns

**Built (code, free, testable):**
- The compliant *composition* of the notice from real decision data.
- The verbatim §701(a) template + agency block, as config.
- The specific-reason selection that avoids the (b)(2)-forbidden boilerplate.
- The FCRA score block (scoped honestly to what we hold today).
- Unit tests (`AdverseActionServiceTest`, 13) + controller tests
  (`AdverseActionNoticeControllerTest`, 5) + the borrower-facing link (`outcomeView`).

**Still owned by compliance / out of scope here (⚖️ / 🤝):**
- Legal sign-off that the wording and reasons are sufficient for each jurisdiction.
- **Delivery + proof of delivery** within 30 days (record that the notice was sent).
- The consumer reporting agency identity + key factors (arrives with the **P3**
  credit-bureau integration; the FCRA block is structured to receive it).
- Counteroffer / incomplete-application notice variants (1002.9(a)(1)(iv), 1002.9(c)).
- State-law notice overlays.

---

## Verification

| Item | How |
|---|---|
| Adverse-action determination | `AdverseActionServiceTest.hardDeclined_isAdverseAction` / `approved_isNotAdverseAction` |
| Specific reasons from explanations | `reasons_areSpecificFromExplanations` |
| HARD_DECLINE ranked first | `reasons_hardDeclineComesFirst` |
| Four-reason cap + dedupe + blank-skip | `reasons_cappedAtLimit`, `reasons_areDeduped`, `blankExplanations_areSkipped` |
| Agency token resolved | `ecoaNotice_resolvesAgencyToken` |
| FCRA disclosure present/absent | `creditScore_producesDisclosure`, `noCreditScore_noDisclosure` |
| Forbidden boilerplate not emitted | `doesNotEmitForbiddenScoreOnlyPhrasing` |
| Graceful null-config | `nullConfig_degradesGracefully` |
| Controller wiring (FAIL parse, FICO lookup, CMDT map) | `AdverseActionNoticeControllerTest` (5) |
| Borrower path | `outcomeView` Jest `offers the notice…` / `fires viewnotice…` |

All Apex tests are **written, not yet executed** — they flip to verified only after R-1
(org login + `sf apex run test -l RunLocalTests`).
