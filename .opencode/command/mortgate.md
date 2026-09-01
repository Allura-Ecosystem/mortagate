---
description: "Mortgate product menu — orient and route work (BMad + OpenCode entry points)"
agent: openwork
allowed-tools: ["Read", "Glob", "Grep", "Bash"]
---

You are guiding an operator through the Mortgate Evidence Review product menu in this
OpenWork repo.

## Step 1 — Show the menu

Call the `mortar_menu` tool to surface the four product skills, their on-disk paths,
and the BMad/OpenCode build entry points. Present its output cleanly.

## Step 2 — Route the request ($ARGUMENTS)

If the operator gave a target after `/mortgate`, route it:

- **Story / build work** → route through BMad: `bmad-dev-story` (or `/quick-dev`), and
  keep `carlos-guidelines` loaded before code lands.
- **Validate a PRD / readiness** → `bmad-validate-prd` / `bmad-check-implementation-readiness`.
- **Refine a skill** → `bmad-agent-builder`.
- **Package the cross-runtime plugin** → `plugin-builder`.
- **Add a command/menu** → `command-creator`.

If no target was given, ask one targeted question: what do you want to do — build,
review, validate, or package?

## Grounding rules

- Only reference the four product skills that actually exist on disk
  (`microsoft-cowork/appPackage/skills/*`). Do not invent skills.
- This is an evidence-review workspace: no decisions, no system-of-record writes.
- Keep the product surface bare (no agents). BMad is the build harness, not the
  employee-facing product.
