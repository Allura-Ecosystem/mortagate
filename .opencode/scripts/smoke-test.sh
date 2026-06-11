#!/usr/bin/env bash
# Quick smoke test for Mortgate harness
set -euo pipefail

echo "=== Harness Smoke Test ==="

# Check agent files
AGENT_COUNT=$(ls .opencode/agent/core/*.md .opencode/agent/subagents/**/*.md 2>/dev/null | wc -l)
echo "Agents: $AGENT_COUNT (expected 7)"

# Check skills
SKILL_COUNT=$(ls -d .opencode/skills/*/ 2>/dev/null | wc -l)
echo "Skills: $SKILL_COUNT (expected 60)"

# Check commands
CMD_COUNT=$(ls .opencode/command/*.md 2>/dev/null | wc -l)
echo "Commands: $CMD_COUNT (expected 33+)"

# Check rules
RULE_COUNT=$(ls .opencode/rules/*.md 2>/dev/null | wc -l)
echo "Rules: $RULE_COUNT (expected 3+)"

# Check context
[ -f .opencode/context/navigation.md ] && echo "Context: navigation.md present" || echo "Context: MISSING"

# Check config
[ -f .opencode/AGENTS.md ] && echo "Config: AGENTS.md present" || echo "Config: AGENTS.md MISSING"
[ -f .opencode/config/permissions.json ] && echo "Config: permissions.json present" || echo "Config: MISSING"

echo "=== Done ==="
