#!/usr/bin/env bash
#
# guard-no-seed-in-prod.sh — Decision #3 promotion guard.
#
# WHY THIS EXISTS:
#   The org was loaded with 614 Kaggle "Home Loan Approval" rows for testing,
#   each tagged "[KAGGLE-SEED]" in Audit_Case__c.Scope__c. Those rows MUST NOT
#   exist in a production org. This guard fails closed if any seed rows are
#   present in the TARGET org, so a promotion to prod is blocked while test
#   data is still resident.
#
# USAGE:
#   bash scripts/guard-no-seed-in-prod.sh <target-org-alias-or-username>
#     exit 0  → no [KAGGLE-SEED] rows found  (safe)
#     exit 1  → seed rows present, OR the check could not be run  (blocked)
#
#   Intended to run against the PROD target immediately before a go-live
#   deploy/data-migration — NOT against the dev org (mortagate-de), which is
#   expected to contain the seed data.
#
# ROLLBACK (how the seed rows are removed — run deliberately, never automatic):
#   sf data delete bulk --sobject Audit_Case__c \
#     --query "SELECT Id FROM Audit_Case__c WHERE Scope__c LIKE '[KAGGLE-SEED]%'" \
#     --target-org <prod>
#
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "✖ guard-no-seed-in-prod: missing target org." >&2
  echo "  Usage: bash scripts/guard-no-seed-in-prod.sh <prod-org-alias>" >&2
  exit 1
fi

SOQL="SELECT COUNT() FROM Audit_Case__c WHERE Scope__c LIKE '[KAGGLE-SEED]%'"

# Query the count; fail closed if the query itself errors (don't assume clean).
if ! RAW="$(sf data query --query "$SOQL" --target-org "$TARGET" --json 2>/dev/null)"; then
  echo "✖ guard-no-seed-in-prod: could not query '$TARGET' — failing closed." >&2
  echo "  Verify the org alias and your access, then re-run." >&2
  exit 1
fi

# totalSize on a COUNT() query is the row count.
COUNT="$(printf '%s' "$RAW" | grep -o '"totalSize"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1)"
COUNT="${COUNT:-unknown}"

if [ "$COUNT" = "unknown" ]; then
  echo "✖ guard-no-seed-in-prod: could not parse the seed-row count — failing closed." >&2
  exit 1
fi

if [ "$COUNT" -gt 0 ]; then
  echo "✖ guard-no-seed-in-prod: $COUNT [KAGGLE-SEED] row(s) present in '$TARGET'." >&2
  echo "  Test/seed data must NOT promote to production. Remove the seed rows first" >&2
  echo "  (see the ROLLBACK command in this script's header), then re-run." >&2
  exit 1
fi

echo "✓ guard-no-seed-in-prod: no [KAGGLE-SEED] rows in '$TARGET' — safe to promote."
exit 0
