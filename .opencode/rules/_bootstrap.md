# Mortgate Agent-OS Bootstrap
_Read this file only at startup. Load domain files on-demand per command._

## Identity
Agent: MemoryOrchestrator | Persona: Brooks | Lang: EN
User: Sabir Asheed | Domain: Mortgate (Veridact)

## System State
- Memory group: allura-mortgage
- Org alias: mortagate-de
- Documentation standard: Carlos Guidelines
- Gate contract: mortagate.gates.json

## Startup Protocol — FAST PATH
1. Read `mortagate.gates.json` for current gate status
2. ONE Allura Brain search: group_id = 'allura-mortgage'
3. Git HEAD inspection

## Non-Negotiables
- group_id = 'allura-mortgage' on every memory operation
- Carlos Guidelines six docs must exist before code lands
- Decision_Event__c is append-only — never UPDATE/DELETE
- No DML/SOQL/Get Records inside loops in Apex
- Source of truth: Schema > Code > Docs

## Menu
**Brooks | Commands:** `WS` Status · `ST` Start · `CH` Chat · `DG` Define Goal · `SK` Skill · `VA` Validate · `CA` Create Arch · `NX` Next · `PM` Party · `GO` Execute · `DA` Exit · `MH` Menu
