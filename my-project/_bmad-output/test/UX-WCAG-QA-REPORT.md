# Veridact UX — WCAG AA QA Report & Palette Fix

_AI-Assisted Documentation. Munari QA pass + Glaser remediation, run 2026-07-01 against `veridactTokens.css` v2.0.0. Contrast ratios computed with the WCAG 2.1 relative-luminance formula, verified programmatically (not from inline comments)._

Memory group: `allura-mortgage` · Owner: Sabir Asheed / Difference Driven

## 1. Munari QA — verified contrast findings

Ratios recomputed from raw token hex at each color's **real use**. Thresholds: 4.5:1 normal text, 3.0:1 large text (≥18pt / 14pt bold) and non-text UI components.

| Pair (use) | Ratio | Need | Result |
|------------|-------|------|--------|
| Charcoal `#1F1E1C` on Cream `#F5F0E8` (body) | 15.6:1 | 4.5 | ✅ |
| Charcoal on Card `#ffffff` (body) | 17.9:1 | 4.5 | ✅ |
| Ink-muted `#645D53` on Cream (secondary text) | 5.73:1 | 4.5 | ✅ |
| **`--veridact-white-60` (charcoal @0.5) on Cream** | **3.15:1** | 4.5 | ❌ FAIL |
| **Orange `#E25D22` text on Cream (normal)** | **3.18:1** | 4.5 | ❌ FAIL |
| Orange `#E25D22` text on Cream (large only) | 3.18:1 | 3.0 | ✅ (large only) |
| **White `#ffffff` label on Orange `#E25D22` CTA** | **3.61:1** | 4.5 | ❌ FAIL |
| Charcoal `#1F1E1C` on Orange `#E25D22` CTA | 4.62:1 | 4.5 | ✅ |
| Border `#D7CCBB` on Cream | 1.40:1 | 3.0 | ⚠️ decorative-only |
| Chip approved: white on `#16734a` | 5.86:1 | 4.5 | ✅ |
| Chip conditions: charcoal on `#E25D22` | 4.62:1 | 4.5 | ✅ |
| Chip review: white on `#345182` | 7.94:1 | 4.5 | ✅ |
| Chip declined: white on `#8a3324` | 8.14:1 | 4.5 | ✅ |

**Three real defects** (not the stale 06-11 list — the v2.0.0 migration already fixed Amber): `--veridact-white-60` used as text, orange as normal-size text, and white labels on the orange accent. Decision chips all pass.

## 2. Glaser remediation — one new token

| Fix | Token | Value | Proof |
|-----|-------|-------|-------|
| Orange that carries text meaning | `--veridact-accent-strong` | `#B8441A` | text on cream 4.77:1 ✅ · white label on it 5.41:1 ✅ |
| Muted text | use `--veridact-ink-muted` | `#645D53` | 5.73:1 ✅ (stop using `--veridact-white-60` for text) |
| Border | `--veridact-border` | `#D7CCBB` | keep — mark decorative, never sole carrier of meaning |

`#B8441A` is the smallest brand-faithful shift off `#E25D22` that clears AA in **both** directions, so it covers links, orange text, and white-label CTAs with a single addition. `#E25D22` stays as the surface/large-text accent. Applied to `veridactTokens.css` (ADR-UX-01).

**Usage rules:** normal-size orange text or any white-on-orange → `--veridact-accent-strong`. Charcoal-on-orange stays valid at 4.62:1. `--veridact-white-60` is decorative only.

## 3. Brand → SLDS design-token map

Bind Veridact vars to SLDS global styling hooks so components use one system and inherit theming/accessibility. Never hardcode hex in LWCs.

| Veridact token | Value | SLDS global styling hook |
|----------------|-------|--------------------------|
| `--veridact-surface` | `#F5F0E8` | `--slds-g-color-surface-1` |
| `--veridact-card` | `#ffffff` | `--slds-g-color-surface-container-1` |
| `--veridact-ink` | `#1F1E1C` | `--slds-g-color-on-surface-1` |
| `--veridact-ink-muted` | `#645D53` | `--slds-g-color-on-surface-2` |
| `--veridact-accent-strong` | `#B8441A` | `--slds-g-color-accent-container-1` / brand button bg |
| `--veridact-border` | `#D7CCBB` | `--slds-g-color-border-1` |
| `--veridact-approved` | `#16734a` | success container |
| `--veridact-review` | `#345182` | info container |
| `--veridact-declined` | `#8a3324` | error container |

## 4. Exit criteria (UX "right")

1. `veridactTokens.css` updated with `--veridact-accent-strong` ✅ (done)
2. No LWC uses white-on-`#E25D22` or `--veridact-white-60` for text — enforced by sa11y gate (see `sa11y` test scaffold)
3. Brand→SLDS map applied in components
4. ADR-UX-01 promoted to Allura under `allura-mortgage` (HITL curator approval)
