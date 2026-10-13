# Change Management — Skill Edits

**Applies to:** every file under `appPackage/skills/` and `skills/`
**Control ID:** E-3 in `my-project/_bmad-output/test/CONTROL-MATRIX.md`

## Why this exists

The skills in this package are prompts. A `SKILL.md` edit changes system
behaviour with no compile step, no type check, and no automatic test gate — one
sentence can widen the authority boundary and nothing mechanical will object.

That is the property model-risk review flags first on an AI system: behaviour
that changes without a build. This document is the gate that replaces the missing
compiler.

## Change classes

| Class | Examples | Gate |
|---|---|---|
| **Boundary** | Any edit to a `## Safety boundary` section, to `references/safety-boundaries.md`, or to prohibited-action wording | Full gate + named approver |
| **Behavioural** | Workflow steps, output table columns, status taxonomy, handoff routing | Full gate |
| **Descriptive** | Trigger phrases in frontmatter `description`, wording that does not change what the skill does or refuses | Refusal suite only |
| **Editorial** | Typos, formatting, comments | None |

When the class is unclear, treat the change as the more restrictive of the two.

## The gate

Before a boundary or behavioural change merges:

1. **Re-run the refusal suite (CW-16..22).** All seven must refuse and cite a
   boundary. Any partial compliance blocks the merge.
2. **Re-run the affected skill against `pilot-fixtures/`.** Score blind — produce
   findings first, read `pilot-fixtures/README.md` ground truth only afterward.
3. **Record the run** as a dated evidence file in
   `my-project/_bmad-output/test/`, following
   `cowork-skills-dry-run-2026-09-02.md`. Include what regressed as well as what
   passed.
4. **Update `CONTROL-MATRIX.md`** for any control whose mechanism, test, or
   result changed.
5. **Boundary changes additionally require a named approver** recorded in the
   commit message. A boundary may be narrowed without further review; widening
   one — permitting an action previously refused — requires business-owner and
   compliance sign-off before merge.

## Version and provenance

- Increment `appPackage/manifest.json` for any boundary or behavioural change.
- `appPackage/skills/` is the canonical source currently present in this
  repository. This directory does not currently ship a `.claude-plugin/` or
  parallel root `skills/` distribution. Downstream Claude/Codex distributions
  must be generated from the pinned canonical skills and checked for parity;
  do not edit a downstream copy as the source of truth.

## What this gate does not cover

Connector-stage controls (`CONNECTOR-ROADMAP.md` §1–7) are not implemented and
are therefore out of scope here. When a connector is built, tool-level changes
need their own gate covering scope enforcement, `readOnlyHint` annotations, and
the audit pathway.

## 0.2.1 — adaptive review context (2026-10-13)

Behavioural update: all four skills reuse cited same-case context, invalidate
changed inputs, inherit the host model choice, and avoid redundant intake for a
clear authorized review. Safety boundary sections and reference files are
unchanged. This is a local source update, not a tenant deployment or merge.

Validation performed: offline package structure; exact catalog-export contract;
existing export unit tests; documentation links; unchanged safety-section and
reference comparison against the parent commit. In-session refusal and fixture
walkthrough details are recorded in the repository's dated test evidence. That
walkthrough is not a blind host-runtime eval, because prior fixture expectations
were already present in the review context. A fresh independent blind run and
Microsoft tenant checks remain required before claiming the full change gate
passed or tenant readiness. No latency or model-quality improvement is claimed
without runtime measurements.
