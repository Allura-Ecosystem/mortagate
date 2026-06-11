# US-1.4: Verify Mobile-First at 375px

**Epic:** EP-1 — Journey Orchestration + UX Hardening
**FRs:** NFR-2
**ADRs:** None
**Priority:** P0
**Depends on:** US-1.0 (brand tokens applied), US-1.1 (orchestrator renders all 6 screens)

## Acceptance Criteria

- All 6 screens render correctly at 375px viewport width
- No horizontal scroll on any screen at 375px
- All interactive touch targets are ≥44px height and width
- Text is readable at default browser font size without user zoom
- Verified in Chrome DevTools mobile emulation (iPhone SE preset, 375x667)
- Verified on at least one physical device (iOS or Android)
- Any CSS fixes applied are token-based (no hardcoded values introduced)

## Files to Create/Modify

No new files. Potential CSS tweaks only:

- `force-app/main/default/lwc/welcomeGate/welcomeGate.css`
- `force-app/main/default/lwc/intentCapture/intentCapture.css`
- `force-app/main/default/lwc/preCheckResult/preCheckResult.css`
- `force-app/main/default/lwc/evidenceQueue/evidenceQueue.css`
- `force-app/main/default/lwc/decisionRoom/decisionRoom.css`
- `force-app/main/default/lwc/outcomeView/outcomeView.css`
- `force-app/main/default/lwc/progressIndicator/progressIndicator.css` (from US-1.2)

## Test Plan

Manual verification checklist (run against deployed or local scratch org):

1. Open Chrome DevTools > Toggle Device Toolbar > iPhone SE (375x667)
2. Navigate to Experience Cloud borrower site as guest
3. For each of the 6 screens:
   - [ ] No horizontal scrollbar visible
   - [ ] Heading text not clipped
   - [ ] CTA button ≥44px tall (inspect with DevTools ruler)
   - [ ] Progress indicator visible above fold
   - [ ] Form inputs (if any) full-width, not overflowing
4. Repeat on physical device — note device model in story comments

## Context

All LWC CSS already uses `min-height: 100dvh`, flex column layout, and `padding: 24px`/`32px`. The two primary risk areas for 375px breakage are:

1. Outfit Bold at display sizes (e.g., `font-size: 2.5rem` headings) — may need to drop to `2rem` at narrow viewport via `@media (max-width: 400px)`
2. Progress indicator (US-1.2) fitting in one row at 375px — if 4-phase labels overflow, use abbreviated labels (Intent, Docs, Review, Decision) or icon-only at narrow widths

Do not introduce any new breakpoints above 375px. The design is mobile-first; desktop is just a wider canvas with the same component.
