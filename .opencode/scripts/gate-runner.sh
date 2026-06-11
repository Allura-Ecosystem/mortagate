#!/usr/bin/env bash
# Gate runner for mortagate.gates.json
# Usage: bash .opencode/scripts/gate-runner.sh [phase]

set -euo pipefail
PHASE="${1:-all}"

echo "=== Mortgate Gate Runner ==="
echo "Phase: $PHASE"
echo ""

# Phase 0: Workspace
if [[ "$PHASE" == "all" || "$PHASE" == "0" ]]; then
  echo "--- Phase 0: Workspace ---"
  sf org display --target-org mortagate-de > /dev/null 2>&1 && echo "PASS: org authenticated" || echo "FAIL: org not authenticated"
  [ -f sfdx-project.json ] && echo "PASS: sfdx-project.json" || echo "FAIL: sfdx-project.json missing"
  [ -f mortagate.gates.json ] && echo "PASS: mortagate.gates.json" || echo "FAIL: mortagate.gates.json missing"
fi

# Phase 1: Carlos Docs
if [[ "$PHASE" == "all" || "$PHASE" == "1" ]]; then
  echo "--- Phase 1: Carlos Docs ---"
  for doc in BLUEPRINT.md SOLUTION-ARCHITECTURE.md REQUIREMENTS-MATRIX.md RISKS-AND-DECISIONS.md DATA-DICTIONARY.md; do
    [ -f "_bmad-output/planning-artifacts/$doc" ] && echo "PASS: $doc" || echo "FAIL: $doc missing"
  done
  ls _bmad-output/planning-artifacts/DESIGN-*.md > /dev/null 2>&1 && echo "PASS: DESIGN-*.md" || echo "FAIL: no DESIGN docs"
fi

# Phase 2: Quality
if [[ "$PHASE" == "all" || "$PHASE" == "2" ]]; then
  echo "--- Phase 2: Quality ---"
  npm test -- --runInBand 2>/dev/null && echo "PASS: Jest" || echo "FAIL: Jest"
fi

echo ""
echo "=== Gate Runner Complete ==="
