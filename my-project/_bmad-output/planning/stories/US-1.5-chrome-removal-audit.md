# US-1.5: Audit Experience Cloud Chrome Removal

**Epic:** EP-1 — Journey Orchestration + UX Hardening
**FRs:** NFR-5
**ADRs:** None
**Priority:** P0
**Depends on:** US-1.0 (Veridact brand tokens applied before audit)

## Acceptance Criteria

- Zero Salesforce header, nav bar, footer, or Salesforce branding visible on any borrower-facing page
- Only Veridact design tokens and components render in the guest and authenticated borrower views
- Guest user (unauthenticated) reaches the Welcome Gate without encountering a Salesforce login wall
- Screenshots captured for all 6 screens in both guest and authenticated states as evidence
- Verification checklist completed and attached to story

## Files to Create/Modify

- Experience Cloud site configuration (Builder settings — no file representation in force-app)
- Community page layouts in Experience Builder if header/footer components need removal
- `force-app/main/default/experiences/` — if any page config is tracked as metadata, update there
- No LWC source changes expected unless a component is accidentally exposing Salesforce chrome

## Test Plan

This story cannot be fully verified without access to `mortagate-de` org. Steps:

1. Deploy all EP-1 LWC changes to `mortagate-de`:
   ```bash
   sf project deploy start --target-org mortagate-de
   ```
2. Open Experience Cloud site URL as guest (incognito, no Salesforce session)
3. For each of the 6 screens capture a screenshot
4. Verify checklist:
   - [ ] No Salesforce logo in header
   - [ ] No "Powered by Salesforce" footer
   - [ ] No standard Salesforce navigation bar
   - [ ] No login prompt on Welcome screen (guest access enabled)
   - [ ] Background is Cream `#F5F0E8`, not Salesforce blue/white default
   - [ ] Font is Outfit Bold, not Salesforce Sans
5. Repeat steps 2-4 logged in as a borrower community user

## Context

Experience Cloud chrome removal is controlled in Experience Builder (Setup > Digital Experiences > Builder), not in LWC source. The main levers are:

- **Theme**: set to custom theme using Veridact tokens; disable default header/footer regions
- **Guest user profile**: must have Read access to the community pages but no Salesforce app nav
- **Login page**: configure community to use custom login or bypass for public pages

If chrome persists after Builder config, check whether the community page template is "Microsite" or "LWR" — both support headless config. Do not use "Aloha" template as it forces the Salesforce header.

Cannot mark this story Done until `mortagate-de` is accessible and screenshots are attached.
