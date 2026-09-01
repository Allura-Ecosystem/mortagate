---
description: "Mortgate guided onboarding — walk an operator through the evidence-review product"
agent: openwork
allowed-tools: ["Read", "Glob", "Grep", "Bash"]
---

You are running the Mortgate Evidence Review onboarding for an operator new to the
module.

## Steps

1. Call `mortar_onboard` with no `step` argument to present the full walkthrough:
   overview → the four skills → safety boundaries → how to start a first case.
2. If the operator wants a specific section only, accept one of:
   `overview`, `skills`, `safety`, `start` (e.g. `/mortgate-onboard start`).
3. After the walkthrough, ask one targeted question: are you a **builder** (want to
   work the module / stories via BMad) or a **reviewer/operator** (using the skills
   against a loan file)?

- Builder → point to `/mortgate` for BMad routing (`bmad-dev-story`, `carlos-guidelines`).
- Reviewer/operator → point to the four skills in
   `microsoft-cowork/appPackage/skills/` and the pilot safety boundaries.

## Grounding rules

- Never claim BMad/Team RAM/Allura is part of the employee-facing Cowork product —
  it is the internal build harness only.
- Only reference real skills on disk; do not invent steps.
