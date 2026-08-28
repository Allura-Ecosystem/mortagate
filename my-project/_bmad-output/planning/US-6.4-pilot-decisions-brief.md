# US-6.4 — Pilot Decisions Brief

**Status:** Awaiting Sabir's rulings · **Date:** 2026-08-28 · **Owner:** Sabir
**Purpose:** The 3 open items from `planning/DESIGN-cowork-pilot-onboarding.md` presented
with recommendations so a single approval session closes the story. Each item shows the
options and the recommended default. **Recommendations are defaults, not decisions** —
per the UX doc, these are "decisions for Sabir, not defaults to assume."

---

## Decision 1 — Pilot invite/licensing mechanics

**Question:** Who provisions Frontier-tenant access for each pilot cohort member, and how?

| Option | Mechanics | Cost/Effort | Risk |
|---|---|---|---|
| **A. Sabir provisions (recommended)** | Sabir (org owner) creates the pilot M365 group, assigns Copilot + Cowork (Frontier preview) licenses, sends invites with a one-page onboarding note | ~1–2 hrs for a cohort of 3–5 | None — direct control of tenant scope |
| B. IT/tenant admin provisions | Hand off to the org's M365 admin with a written request | Depends on IT backlog | Delay; loss of direct control |
| C. Shared device/session | One licensed seat, pilot users take turns | Zero licensing cost | Contaminates "Only you" uploads; users can't test concurrently |

**Recommendation: A.** Cohort size 3–5 is small enough that Sabir's direct provisioning
is one afternoon. The Frontier-preview gate (Cowork requires a Frontier-enabled tenant)
means a license-holder must be present anyway for US-6.6.

**If you pick A**, the invite note and license checklist are drafted in
`US-6.6-tenant-validation-runbook.md`.

---

## Decision 2 — Synthetic document fixture source

**Question:** Shared fixture set provided to all pilot users, or each user supplies their own?

| Option | Description | Pros | Cons |
|---|---|---|---|
| **A. Shared pack (recommended)** | One versioned fixture pack in-repo (20+ synthetic docs, clearly bannered NON-PRODUCTION), all pilot users upload the same files | Comparable results across cohort; CW-5 missing-evidence accuracy is verifiable against a known-incomplete pack; conflicts/ambiguities deliberately planted | None material |
| B. Self-supplied | Each user brings their own synthetic docs | None for our goals | Results not comparable; CW-5/CW-7 can't be verified against a known ground truth |

**Recommendation: A.** The pack now exists at
`my-project/_bmad-output/pilot-fixtures/` — a complete file, an incomplete file (missing
docs planted for CW-5), an income-conflict pair (CW-7), an undated doc (CW-6), and an
unidentified doc (CW-4). Every document is bannered `SYNTHETIC — NOT A REAL BORROWER
DOCUMENT`. All pilot users should upload the **incomplete** file first (exercises
CW-1..CW-5 + CW-16..CW-22), then the conflict pair.

**If you pick A**, distribution is just: point the cohort at the pack's README.

---

## Decision 3 — Feedback capture channel

**Question:** Where does pilot feedback land so US-6.8 has a real input rather than word-of-mouth?

| Option | Channel | Pros | Cons |
|---|---|---|---|
| **A. Structured form → planning/ dir (recommended)** | A `feedback/` document per pilot user (template included), written by the user or captured in a Brooks session; stored in `my-project/_bmad-output/planning/pilot-feedback/` | Durable, greppable, feeds US-6.8 directly; no external tooling | Slightly more effort than a chat message |
| B. Slack/Teams channel | A dedicated channel | Familiar | Not everyone's on it; content is ephemeral |
| C. Direct session with Brooks | Each user debriefs in a session | Rich detail | Serial; only as good as the notes taken |

**Recommendation: A.** The template is at the bottom of this document. US-6.8's AC
("feedback collected from every pilot-cohort member, not just volunteers") is easiest to
prove with one file per user. Brooks can run the capture session if a user prefers to
talk rather than type.

---

## The three rulings, in one line each

1. **Licensing:** *I provision the pilot M365 group + licenses myself* (A) — or name the admin who will.
2. **Fixtures:** *Use the in-repo shared pack* (A) — or say each user self-supplies.
3. **Feedback:** *Store per-user feedback docs in planning/pilot-feedback/* (A) — or name the channel.

Reply with "1A 2A 3A" (or your choices) and US-6.4 closes immediately.

---

## Pilot feedback template (for Decision 3)

```markdown
# Pilot Feedback — <name> (<date>)

## Overall
<!-- One or two sentences on the general feel of the module. -->

## What worked
<!-- What felt clear, useful, accurate. Name the skill/step if possible. -->

## What didn't
<!-- Confusing outputs, unclear refusals, wrong-looking findings. Exact wording helps. -->

## Refusals
<!-- Any request you made that was refused? Was the refusal understandable? (CW-22) -->

## Missing evidence (CW-5)
<!-- Did the missing-document list match what you knew was absent? -->

## Anything else
<!-- Open text. -->
```

---

**Assessed by:** Brooks · **Date:** 2026-08-28 · **Blocks:** US-6.4, US-6.7
