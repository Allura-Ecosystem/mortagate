#!/usr/bin/env bash
#
# CaseFile / Mortagate — phase-2 org gate + commit, 2026-07-26
#
# Proves the Sort_Order__c determinism fix against a live org, then commits it.
# Piecewise deploy slices are canonical per ADR-22/25 and are copied verbatim
# from mortagate.gates.json p2-002 — do not collapse them into one deploy.
#
# Run from the repo root:
#   bash my-project/_bmad-output/implementation/gate-phase2-2026-07-26.sh
#
# Fails fast. If a step fails, stop and read the JSON — do not skip ahead.

set -euo pipefail

ORG=mortagate-de
cd "$(git rev-parse --show-toplevel)"

echo "=== 0. Auth check (phase-0 p0-001/p0-002) ==============================="
sf --version
sf org display --target-org "$ORG"
# If this fails, authenticate first and re-run:
#   sf org login web --alias mortagate-de --set-default
# Sandbox instead of a dev org:
#   sf org login web --alias mortagate-de --instance-url https://test.salesforce.com --set-default

echo "=== 1. Gate p2-002 — piecewise DRY RUN (4 slices) ======================="
sf project deploy start --source-dir force-app/main/default/objects \
  --target-org "$ORG" --dry-run

sf project deploy start --source-dir force-app/main/default/classes \
  --source-dir force-app/main/default/triggers \
  --target-org "$ORG" --dry-run

sf project deploy start --source-dir force-app/main/default/lwc \
  --source-dir force-app/main/default/staticresources \
  --target-org "$ORG" --dry-run

sf project deploy start --source-dir force-app/main/default/flexipages \
  --source-dir force-app/main/default/tabs \
  --source-dir force-app/main/default/applications \
  --source-dir force-app/main/default/permissionsets \
  --target-org "$ORG" --dry-run

echo "=== 2. REAL deploy — order matters ======================================"
# Objects first: Policy_Rule__c.Sort_Order__c must exist before the Apex that
# selects it will compile, and before the permission set can grant FLS on it.
sf project deploy start --source-dir force-app/main/default/objects \
  --target-org "$ORG"

sf project deploy start --source-dir force-app/main/default/permissionsets \
  --target-org "$ORG"

sf project deploy start --source-dir force-app/main/default/classes \
  --source-dir force-app/main/default/triggers \
  --target-org "$ORG"

echo "=== 3. Prove the field actually landed =================================="
sf data query --target-org "$ORG" \
  --query "SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Policy_Rule__c' AND QualifiedApiName = 'Sort_Order__c'" \
  --use-tooling-api
# Expect exactly 1 row. Zero rows means the objects slice silently skipped it.

echo "=== 4. Gate p2-003 — targeted determinism tests first ==================="
# Run the three new tests on their own so a failure elsewhere cannot mask them.
sf apex run test --target-org "$ORG" \
  --tests ReplayServiceTest.determinism_sortOrderDrivesEvaluationOrder \
  --tests ReplayServiceTest.determinism_replayTwice_producesIdenticalSequence \
  --tests ReplayServiceTest.determinism_nullSortOrder_sortsLast \
  --result-format human --wait 10

echo "=== 5. Gate p2-003 — full suite + coverage =============================="
sf apex run test --target-org "$ORG" --result-format human --code-coverage --wait 20

echo "=== 6. Commit ==========================================================="
git status --short
git add \
  "force-app/main/default/objects/Policy_Rule__c/fields/Sort_Order__c.field-meta.xml" \
  "force-app/main/default/permissionsets/Veridact_Mortgage_Engine_Access.permissionset-meta.xml" \
  "force-app/main/default/classes/ReplayService.cls" \
  "force-app/main/default/classes/ReplayServiceTest.cls" \
  "force-app/main/default/classes/SeedDataLoader.cls" \
  "force-app/main/default/classes/SabirSrSmokeTest.cls" \
  "my-project/_bmad-output/planning-artifacts/EPICS-AND-STORIES.md" \
  "my-project/_bmad-output/planning/implementation-readiness-report-2026-07-26.md" \
  "my-project/_bmad-output/planning/implementation-readiness-report-2026-06-11.md" \
  "my-project/_bmad-output/implementation/gate-phase2-2026-07-26.sh"

git commit -m "fix(replay): pin rule evaluation order with Policy_Rule__c.Sort_Order__c

DATA-DICTIONARY §2.5 specified Sort_Order__c (FR-28) but it was never
implemented. Three separate helpers — SeedDataLoader.makeRule(),
ReplayServiceTest.buildRule() and SabirSrSmokeTest.buildRule() — accepted a
sortOrder argument and silently discarded it, so ten call sites passed 0-9
into a void.

Replays were still deterministic before this change, via the
ORDER BY Rule_Code__c ASC tiebreaker already in ReplayService. But that was
determinism by alphabetical accident, silently breakable by anyone choosing a
new rule code. Sort_Order__c makes the contract explicit at the schema level.

Ordering is pinned query-side in the assembler, not in the evaluator: ADR-5
forbids SOQL in PolicyRuleEvaluator, and a schema-level ORDER BY survives
refactoring better than an in-memory sort. NULLS LAST keeps an unsorted new
rule from jumping the queue; Rule_Code__c remains the tiebreaker.

Sort_Order__c is deliberately not carried into the adapted
Policy_Rule_Version__c — the pure evaluator must consume the list in the order
the assembler hands it over. Persisted order is re-derived from the evaluator
output index at commit time.

FLS note: every other Policy_Rule__c field is universally required, which is
why the permission set had no Policy_Rule__c entries. Sort_Order__c is
optional, so without an explicit grant the WITH USER_MODE rule fetch would
silently drop it for non-admins.

Tests: three determinism tests added — Sort_Order__c drives evaluation order
(with a guard that fails if the fixture ever becomes alphabetical and stops
discriminating), two replays produce an identical sequence, and a null
Sort_Order__c sorts last despite an alphabetically-first rule code.

Docs: EP-0 reconciled to 36/36 in source. New readiness report supersedes
2026-06-11, which is now bannered — it named the retired intake product and
its story IDs have since been reused for different work.

Refs: FR-28, ADR-5, ADR-22, ADR-25, US-0.2
Group: allura-mortgage"

git push

echo "=== DONE — EP-0 is gate-proven if every step above passed ==============="
