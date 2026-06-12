# Screen-Reader Test Plan — Audit Queue (V3.1)

The last open accessibility artifact is a **manual** assistive-technology pass,
which cannot be automated headlessly. This is the script for a human to execute
and record. The automated a11y contract it complements is already green (Jest:
"conveys risk by a text value, not color alone"; "exposes the load-error state
with role=alert").

## Scope

Component: `c-audit-queue` (Audit Queue screen) on `mortagate-de`.

## Environment matrix (run at least one screen reader + browser pair)

| Screen reader | OS | Browser |
|---|---|---|
| NVDA (latest) | Windows | Chrome or Firefox |
| VoiceOver | macOS | Safari |

Also run once with the OS in **dark mode** to confirm V3.3 (SLDS hooks) renders
legibly and the risk tiers are still distinguishable.

## Test cases — record Pass / Fail + notes for each

### A. Page structure & landmarks
- [ ] **A1** The screen title ("Audit Queue") is announced as a heading; heading
      levels are sequential (no skipped levels).
- [ ] **A2** Metric cards are reachable and each value is announced *with* its
      label (e.g. "Critical, 12"), not as a bare number.

### B. Risk tier — non-color discrimination (WCAG 1.4.1)
- [ ] **B1** For each tier, the screen reader announces the tier **word**
      (Critical / High / Medium / Low) from the cell text — the tier is never
      conveyed by colour or by the sigil alone.
- [ ] **B2** The shape sigil (●▲◆■) is decorative and does **not** add noise to
      the announcement (it should be silent or non-disruptive to the cell text).
- [ ] **B3** With a colour-blindness simulator (or greyscale), High / Medium /
      Low remain distinguishable by **shape**, and Critical also by its underline.

### C. Data table
- [ ] **C1** Column headers are announced when navigating cells (row/column
      context is preserved).
- [ ] **C2** Borrower name is announced from the write-once snapshot; an empty
      snapshot reads as empty, not "undefined".
- [ ] **C3** Sortable columns expose their sort state; activating a sort is
      announced (ascending/descending) and row order updates.

### D. Filters
- [ ] **D1** Each filter control has an accessible name (label announced on focus).
- [ ] **D2** Changing a filter updates the table and the change is perceivable to
      AT (e.g. result count or a status announcement).

### E. Error state
- [ ] **E1** Force a load error; confirm the message is announced via
      `role="alert"` without moving focus, and the text is meaningful.

### F. Keyboard only (no mouse)
- [ ] **F1** All interactive elements are reachable in a logical tab order.
- [ ] **F2** Focus is always visible.
- [ ] **F3** No keyboard trap.

## Result record (fill in on execution)

| Field | Value |
|---|---|
| Date | |
| Tester | |
| SR + browser + OS | |
| Dark-mode pass? | |
| Overall result | Pass / Pass-with-notes / Fail |
| Defects filed | (links) |

> File the completed copy alongside the release evidence. A "Pass" or
> "Pass-with-notes" here lifts the final a11y artifact for the deploy checklist.
