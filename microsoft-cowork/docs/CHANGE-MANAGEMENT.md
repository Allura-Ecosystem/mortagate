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

- The package version in `.claude-plugin/plugin.json` and
  `appPackage/manifest.json` must be incremented for any boundary or behavioural
  change.
- Both distribution targets are emitted from one source. A skill edit that lands
  in `skills/` but not `appPackage/skills/` — or the reverse — is a defect: the
  Claude and Microsoft channels would then enforce different boundaries.
  Verify both before merge.

## What this gate does not cover

Connector-stage controls (`CONNECTOR-ROADMAP.md` §1–7) are not implemented and
are therefore out of scope here. When a connector is built, tool-level changes
need their own gate covering scope enforcement, `readOnlyHint` annotations, and
the audit pathway.
