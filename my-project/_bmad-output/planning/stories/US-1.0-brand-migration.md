# US-1.0: Migrate Veridact Brand to Figma Kit v1.0.1

**Epic:** EP-1 — Journey Orchestration + UX Hardening
**FRs:** NFR-3, NFR-5
**ADRs:** ADR-9 (updated), ADR-13
**Priority:** P0 — blocks all other EP-1 visual work
**Depends on:** None

## Acceptance Criteria

- `veridactTokens.css` updated to v2.0.0 token set
- All 6 LWC CSS files reference new palette tokens (no raw hex values from old Indigo palette)
- WCAG AA verified for all text combinations:
  - Charcoal on Cream: 14.68:1 (passes)
  - Charcoal on Orange CTA: 4.62:1 (passes)
  - Chip background text combos: ≥4.5:1 each
- Display font changed from Source Serif 4 to Outfit Bold in token file and CSS
- `npm run test:unit` passes with zero failures after changes

## Files to Create/Modify

- `force-app/main/default/lwc/veridactTokens/veridactTokens.css` — update all color and font tokens to v2.0.0
- `force-app/main/default/lwc/welcomeGate/welcomeGate.css` — swap palette references
- `force-app/main/default/lwc/intentCapture/intentCapture.css` — swap palette references
- `force-app/main/default/lwc/preCheckResult/preCheckResult.css` — swap palette references
- `force-app/main/default/lwc/evidenceQueue/evidenceQueue.css` — swap palette references
- `force-app/main/default/lwc/decisionRoom/decisionRoom.css` — swap palette references
- `force-app/main/default/lwc/outcomeView/outcomeView.css` — swap palette references
- `planning docs/BLUEPRINT.md` — update §B2 (color palette) and §B8 (design rules)
- `my-project/_bmad-output/planning/DESIGN-onboarding-ux.md` — update visual direction section

## Test Plan

- Run `npm run test:unit` — must pass clean
- Manual: load each screen in browser, visually confirm cream background, Outfit Bold headings
- Contrast check: use browser DevTools accessibility panel or axe extension on each screen
- Verify no Indigo `#1b2b5e` hex values remain in any LWC CSS file (`grep -r "1b2b5e"`)

## Context

This is a dark-to-light paradigm shift. The background flips from Indigo `#1b2b5e` to Cream `#F5F0E8`. Every design decision downstream assumes light background.

Key token changes:
- `--color-bg-primary`: `#1b2b5e` → `#F5F0E8` (Cream)
- `--color-text-primary`: light → Charcoal `#2C2C2C`
- `--color-cta`: keep Orange `#E07B39` (CTA contrast verified)
- `--color-approved`: keep `#16734a` — do NOT switch to Figma green `#308357` (fails WCAG at 4.10:1)
- `--font-display`: `'Source Serif 4'` → `'Outfit'` weight 700
- All overlays, borders, and focus outlines must invert to work on light background
