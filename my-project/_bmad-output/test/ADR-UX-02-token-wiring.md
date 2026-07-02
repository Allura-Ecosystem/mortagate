# ADR-UX-02 — Veridact token wiring: the v2.0.0 brand migration is NOT wired into components

> **UPDATE 2026-07-01 (Team Durham / Kotler) — R-3 RESOLVED → ORANGE; stages 2–3 executed at the component layer.**
> User directed "Team Durham follow brand guidelines." Kotler ratified R-3 in favor of the locked brand kit (cream + orange) — this is adoption of an already-locked STP, not new creative. All 11 LWC stylesheets were rewired from the legacy "Figma blue kit" to the Veridact palette using the `var(--veridact-TOKEN, #brandhex)` pattern, so components render on-brand **whether or not** the static resource is wired (this de-risks G1 for the demo and makes them wired-ready). Accent mapping applied: interactive/buttons-white-text/links → `--veridact-accent-strong #B8441A` (white 5.41:1 ✅, on-cream 4.77:1 ✅); decorative bars/badges → `--veridact-proof-amber #E25D22`. Blue tint fills (#eef2ff/#f3f6ff/#e8eefb) retinted to warm/semantic tints. `.signoff-btn:hover` corrected to a *darker* orange (#8f3413, white 7.9:1) to preserve contrast. Only remaining legacy blue is the categorical KPI rail `.rail-blue`, intentionally mapped to the sanctioned `--veridact-link` token. **Still open:** G1 (deploy + wire static resource to `mortagate-de`) and G3 (visual QA in a rendered org) — both require an authenticated org. The token guard (§7) stays red by design until stage 5 (drop the hex fallbacks *after* G1 lands).

> **UPDATE 2026-07-01 (CLI deploy) — RE-SKIN IS LIVE IN `mortagate-de`.**
> Deployed via `sf project deploy start --metadata LightningComponentBundle StaticResource` (deploy id `0AfgL00000QBKqrSAH`, 13/13 components Succeeded). All 12 auditor LWCs + `veridactTokens` static resource (Id `081gL000002BSW5QAO`) are now in the org and render cream+orange via the `var(--veridact-*, #brandhex)` fallbacks. NOTE: the **full-tree** `force-app` deploy fails server-side with `UNKNOWN_EXCEPTION` (0 component errors — a non-LWC metadata type poisons the package; LWC subset is clean and org-portable). G1 re-scoped below.
>
> **G1 re-scope:** There is **no Experience Cloud site checked into this repo** (no `experiences`/`digitalExperiences`/`sites` folders), so "wire as site branding CSS" has no target here. And `veridactTokens.css` wraps its vars in `:root`, which does NOT cascade into a shadow root when injected via `loadStyle` (Salesforce wants `:host`). True global wiring therefore = add a `:host` mirror block to the static resource + `loadStyle` in all 12 components — a broad change with **zero visual effect** (fallbacks already paint the brand) that must be paired with G3 browser QA. Deliberately deferred, not blind-shipped, per the low-risk-change principle.

**Status:** Deployed to org — R-3 resolved (orange), re-skin applied AND live in `mortagate-de` (deploy id `0AfgL00000QBKqrSAH`). Screens render on-brand via `var(--veridact-*, #brandhex)` fallbacks. Remaining: optional global token wiring (`:host` + `loadStyle` ×12) paired with G3 visual QA in a browser.
**Date:** 2026-07-01
**Owner:** Sabir / Difference Driven
**Supersedes context:** ADR-UX-01 (WCAG palette fix), US-1.0 ("dark→light brand migration") completion claim
**Memory group:** allura-mortgage
**Classification:** AI-Assisted Documentation

---

## 1. Answer first

The v2.0.0 "cream + orange" brand migration (US-1.0) was **only applied to `veridactTokens.css`**. It was **never wired into any of the 11 LWCs**. The running app still renders the **old "Figma blue kit"** (blue `#1d4ed8`, navy-ink `#18212e`, blue-gray muted `#6a7281`, near-white `#fbf9f3`). Therefore:

- `US-1.0 = complete` is **false** at the component layer. The static resource is correct; the screens are not.
- The 146 hardcoded hexes (46 distinct, 11 files) are **not** the disease — they are the symptom. The disease is: **components run on a parallel, duplicated token system and never consume `--veridact-*`; the static resource is orphaned (0 references).**
- A blind hex→`var(--veridact-*)` codemod would make the app **render colorless**, because the tokens do not resolve (the static resource is not loaded anywhere).

## 2. Evidence (verified 2026-07-01, not trusted from comments)

| Check | Result |
|---|---|
| References to `veridactTokens` / `--veridact-*` / `loadStyle` / `staticresource` in any LWC (js/css/html) | **0** |
| Components with local `:host` "Figma blue kit" token blocks | auditAnalytics, findingDetail, caseReview, signoffReceipt (+ glossaryTerm subset, auditQueue via `--brand-*`) |
| Components hardcoding raw hexes inline (no local tokens) | auditAdmin, auditMetricCards, auditQueueFilters, policyVersions |
| Hardcoded hex occurrences | 146 across 11 CSS files (46 distinct) |
| In-code acknowledgement | `auditQueue.css`: *"palette reconciliation (Figma blue kit vs Veridact orange) is a **pending brand decision** — see plan risk #3"* |

`signoffReceipt.css` is a hybrid — it already uses `--amber: #e25d22` (the Veridact orange) for the accent bar and demo badge, while the rest of the component stays on the blue kit. This is the only place the new brand has bled into a component.

## 3. Root cause

Two parallel design-token systems exist and have drifted:

1. **`--veridact-*`** — the canonical static resource, migrated to cream/orange in v2.0.0. Orphaned.
2. **Local `:host` "blue kit"** (`--ink`, `--muted`, `--accent`, `--canvas`, `--card`, `--pass`, `--fail`, `--warn`) — duplicated per component, still on the pre-migration blue palette. This is what actually paints the UI.

US-1.0 edited (1) and never touched (2), and never connected (1) to the components.

## 4. Canonical mapping (blue-kit local token → Veridact token)

| Local token | Current hex | → Veridact target | Value Δ | Visual risk |
|---|---|---|---|---|
| `--canvas` / `--shell` / bg | `#fbf9f3` | `--veridact-surface` `#F5F0E8` | small | Low — slightly warmer cream |
| `--card` / `--surface` | `#ffffff` | `--veridact-card` `#ffffff` | none | None |
| `--ink` | `#18212e` | `--veridact-ink` `#1F1E1C` | small | Low — navy-black → charcoal |
| `--muted` | `#6a7281` | `--veridact-ink-muted` `#645D53` | medium | Med — blue-gray → warm taupe |
| `--accent` / `--blue` | `#1d4ed8` | **R-3 DECISION** — `--veridact-proof-amber` `#E25D22` (adopt brand orange) **or** `--veridact-link` `#1d4ed8` (keep blue as a sanctioned token) | large | **HIGH — gated on R-3** |
| `--pass` | `#157a4a` | `--veridact-approved` `#16734a` | negligible | None |
| `--fail` / `--violation` | `#b23a22` | `--veridact-declined` `#8a3324` | medium | Med — brighter → deeper red |
| `--warn` / `--exception` | `#8a5a00` | `--veridact-warn` `#8a5a00` | none | None (token value == current) |
| `--amber` | `#e25d22` | `--veridact-proof-amber` `#E25D22` | none | None (already brand) |

Soft status-fill hexes (`#e3f3ea`, `#fbe6e1`, `#eef2ff`, `#fdf0d9`, plus ~10 one-off near-duplicate tints in caseReview/policyVersions/signoffReceipt) → the four semantic tint tokens added in this ADR (`--veridact-approved-tint`, `--veridact-declined-tint`, `--veridact-review-tint`, `--veridact-warn-tint`). Near-duplicate one-offs (e.g. `#fbe9e6` vs `#fbe6e1` vs `#fbeae6`, ΔE < 1) should **consolidate** to the canonical tint, not each get a token — that consolidation changes pixels imperceptibly but still requires a visual pass.

Tokens added to `veridactTokens.css` in support of this ADR (all WCAG-AA verified on cream): `--veridact-accent-strong #B8441A`, `--veridact-link #1d4ed8`, `--veridact-warn #8a5a00`, and the four tint fills above.

## 5. Staged remediation plan (each stage = one reviewable commit)

1. **Wire the static resource.** Make `--veridact-*` resolve in components — either add `veridactTokens.css` as the Experience Cloud site's branding/custom CSS (preferred; applies at `:root`, cascades into all shadow trees), or `loadStyle(this, veridactTokens)` from a shared base component. *Requires the org.* Until this lands, no hex can be safely removed.
2. **Resolve R-3** (blue vs orange accent) with Glaser/Kotler. This is a brand decision, not an engineering one, and the code has deliberately deferred it. Everything else in §4 can proceed without it.
3. **Rewire local `:host` blocks** to `var(--veridact-*)` per §4, one component per commit, **verifying each screen visually** against the Figma brand kit. Start with the 4 raw-hex components (define a local block, then point it at tokens).
4. **Consolidate one-off tints**, visual pass.
5. **Drop hex fallbacks** and let `npm run test:tokens` go green — this is the *last* step, not the first. A green guard before stages 1–3 would be a false green.

## 6. Human gates (why this is not auto-executed)

- **G1 — Org / static-resource wiring:** cannot confirm or perform the Experience Cloud branding wiring without an authenticated `mortagate-de` org.
- **G2 — R-3 brand decision:** blue→orange is an open, deliberately-deferred brand governance decision. Auto-flipping it would override that decision.
- **G3 — Visual verification:** the app cannot be rendered here (no org, no browser). The demo matters; a re-skin cannot ship unverified.

Stages 3–5 are mechanically well-defined and low-risk *once* G1–G3 clear.

## 7. Guard status

`npm run test:tokens` (`scripts/check-brand-tokens.mjs`) **stays red by design** until stage 5. It correctly reports 146 hardcoded hexes today. Do not silence it by tokenizing drift in place — that would launder the parallel blue-kit system into the brand file and hide the unfinished migration.
