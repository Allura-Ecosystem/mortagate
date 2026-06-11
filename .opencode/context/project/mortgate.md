# Mortgate Project Context

## Identity
- **Project:** Salesforce Community Mortgage Approval Engine
- **Brand:** Veridact
- **Org:** mortagate-de (Developer Edition)
- **Memory group:** allura-mortgage

## Tech Stack
- Salesforce Platform (Apex, LWC, Flows, Experience Cloud)
- Jest (LWC unit tests)
- sf CLI (deploy, test, gates)
- Allura Brain (governed memory)

## Architecture
- PolicyRuleEvaluator — generic rule engine evaluating Policy_Rule_Version__c records
- LoanDecisionService — orchestrates fact assembly → rule evaluation → decision creation
- Decision_Event__c — append-only audit trail (never UPDATE/DELETE)
- 7 LWC components for borrower-facing Experience Cloud site

## Naming
- Files: kebab-case
- Apex: PascalCase
- LWC: camelCase
- SObjects: Pascal_Snake__c
- Custom fields: Pascal_Snake__c
- Constants: SCREAMING_SNAKE_CASE
