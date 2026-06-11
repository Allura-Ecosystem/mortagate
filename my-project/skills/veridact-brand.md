# Veridact Brand

**Trigger:** Any LWC, CSS, or HTML change in `force-app/**/lwc/`.

---

## Invariants

- Amber (`#d4920a`) = action only. CTAs and accent bar. Never decorates approval screen.
- Green (`#16734a`) owns the approved outcome.
- Semantic colors are chip/badge backgrounds, not text. All WCAG >= 4.5:1:
  - Approved: `#16734a` bg, white text (5.86:1)
  - Approved w/ Conditions: `#d4920a` bg, indigo text (5.09:1)
  - Pending Review: `#345182` bg, white text (7.94:1)
  - Declined: `#8a3324` bg, white text (8.14:1)
- Amber accent bar: 4px, bottom of every screen, every state. Hard line — no glow, shadow, gradient.
- Source Serif 4: display only (>= 28px). Tagline, headline, verdict. Never in form labels.
- Inter: everything else.
- 8px border-radius. No 24px. No gradients.
- Motion: right-enter, left-exit. Honor `prefers-reduced-motion`.
- Mobile: 375px primary, 100dvh per screen, touch >= 44px, 32px/24px padding (refs `lwc-craft` skill).

## Enforcement Checklist

- [ ] No hardcoded hex colors — all use CSS custom properties / SLDS tokens
- [ ] Verify: `grep -rn '#[0-9a-fA-F]\{6\}' force-app/**/lwc/**/*.css` — hits only in `veridactTokens.css`
- [ ] Amber not used on APPROVED outcome screen
- [ ] Semantic status uses chip component, not colored text
- [ ] All chip color pairs pass WCAG 4.5:1 contrast
- [ ] Source Serif 4 only on display text >= 28px
- [ ] Inter used for all non-display text
- [ ] Border-radius uses 8px token, not 24px
- [ ] No gradient fills on primary surfaces
- [ ] Accent bar present at bottom of screen
- [ ] `prefers-reduced-motion` honored (animations disabled)
- [ ] No Salesforce chrome visible in borrower view

**Source:** ADR-9, DESIGN-onboarding-ux.md (Glaser visual direction).
