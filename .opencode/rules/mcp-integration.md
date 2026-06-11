# MCP Integration — Mortgate

## THE RULE
**NEVER `docker exec` for DB operations. ALWAYS use `mcp__MCP_DOCKER__*` tools.**

## Active Tool Stack
| Tool | Use |
|------|-----|
| `allura-brain__memory_*` | Governed memory (group_id: allura-mortgage) |
| `MCP_DOCKER__notion-*` | Notion workspace ops |

## Boot Policy
Allura Brain (`localhost:5888/mcp`) is the canonical memory surface.
All memory operations use `group_id: "allura-mortgage"`.
