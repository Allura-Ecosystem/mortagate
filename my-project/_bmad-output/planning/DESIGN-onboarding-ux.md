# DESIGN: Borrower Onboarding UX

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

---

## Overview

The borrower onboarding follows Pike's three-state model rendered across six screen components. Mobile-first (375px primary). Aion UI–inspired: conversational, feed-based, no wizard chrome.

---

## Component Specification: `c-welcome-gate`

### Purpose
Full-viewport welcome screen (Screen 1). One sentence, one button, no login wall, no account creation. The borrower sees value before being asked for anything. The headline is borrower-addressed and functional (Inter Medium). The brand tagline appears as a quiet footer signature in Source Serif 4 — it is the signature, not the call to action.

### Props (@api)
None. This component is stateless and receives no external data.

### Events (CustomEvent)
```javascript
// Fired when the borrower taps "Get Started"
this.dispatchEvent(new CustomEvent('start', {
    bubbles: true,
    composed: true
}));
```

### Animation / Interaction
- No motion on this screen. Static composition only.
- Single CTA button ("Get Started") — amber background, indigo text, 8px radius.
- The amber accent bar (4px, `--veridact-proof-amber`) sits at the absolute bottom of the viewport, below the tagline. Present unconditionally.

### Accessibility
- Headline rendered as `<h1>` for document outline.
- CTA `<button>` with `type="button"` — keyboard-focusable by default.
- Focus-visible ring: 2px solid white with 2px offset on the CTA.
- No `aria-live` regions (static content, no dynamic updates).

### Mobile Behavior
- Full viewport height via `min-height: 100dvh`. No scroll within the gate.
- Flexbox column layout with content centered vertically in the `.body` region.
- Padding: 32px vertical, 24px horizontal. Headline max-width constrained to `18ch` to prevent runaway line lengths on wider viewports.
- Tagline positioned at the bottom of the flex column, above the accent bar, with `padding: 0 24px 20px`.

### Copy (locked)
- Headline: "Let's find out what you qualify for."
- Subhead: "Takes about 8 minutes. No account needed to start."
- Tagline: "Every decision has a receipt."
- CTA label: "Get Started"

### Typography
- Headline: Inter Medium (`font-weight: 500`), 32px, line-height 1.15.
- Subhead: Inter, 16px, white at 60% opacity.
- Tagline: Source Serif 4, 18px, white at 60% opacity.
- CTA: Inter Semi-Bold (`font-weight: 600`), 16px.

---

## Component Specification: `c-intent-capture`

### Purpose
Conversational three-question flow that replaces traditional multi-field forms. Each question renders full-screen, one at a time, with slide transitions.

### Props (@api)
```javascript
@api loanPurposeOptions = ['buying', 'refinancing'];  // Q1 choices
@api maxPropertyValue = 5000000;                        // Q2 slider max
@api maxIncome = 1000000;                               // Q3 slider max
```

### Events (CustomEvent)
```javascript
// Fired after all 3 questions answered
this.dispatchEvent(new CustomEvent('intentcaptured', {
    bubbles: true,
    composed: true,
    detail: {
        loanPurpose: 'buying',        // String
        propertyValue: 450000,         // Number
        annualIncome: 120000           // Number
    }
}));
```

### Animation Strategy
- CSS `transform: translateX()` with `transition: transform 0.4s ease-out`
- Three `<div>` panels absolutely positioned. Active panel at `translateX(0)`, answered panel at `translateX(-100%)`, next panel at `translateX(100%)`
- Degrades to instant swap on `prefers-reduced-motion: reduce`
- Tested targets: Chrome 120+, Firefox 120+, Safari 17+, Samsung Internet 23+

### Accessibility
- Each question panel is an `<article>` with `role="group"` and `aria-label`
- Focus auto-moves to the primary interactive element on each slide
- Keyboard: Enter/Space to select button answers, Tab for slider navigation
- Color is never the only indicator — icons accompany all selections

### Mobile Behavior
- Full viewport height (`100dvh`) — no scrolling within a question
- Touch: swipe-left disabled (prevents accidental advancement)
- Input: native number keyboard for income/property fields (`inputmode="numeric"`)

---

## Component Specification: `c-evidence-queue`

### Purpose
Sequential document upload — one document at a time, not a checklist.

### Queue Order
1. Most recent pay stub (income verification)
2. W-2 or 1099 (annual income confirmation)
3. Bank statements — last 2 months (asset verification)
4. Government-issued photo ID (identity verification)
5. Purchase agreement (if buying — conditional)

### Upload Interaction
- Drag-and-drop zone with `<lightning-file-upload>` base component
- Progress bar during upload (indeterminate → percentage as ContentVersion creates)
- On success: green check + encouraging message ("Got it. That's the hardest one." / "Two more to go.")
- On failure: human error message + retry button. No codes.
- Next document auto-reveals after 1.5s delay (feels intentional, not rushed)

### Extraction Trigger
- After ContentVersion is created, a Platform Event or after-save Flow triggers fact extraction
- `c-evidence-queue` polls or subscribes for Extracted_Facts__c records linked to the uploaded Evidence__c
- Shows extracted facts inline: "We found: Annual income $120,000" with a confirm checkbox (view-only; fact correction deferred to EP-4 per ADR-14)

---

## Component Specification: `c-decision-room`

### Purpose
Timeline feed screen (Screen 5). Pike's "Active state" — a single panel that renders Decision_Event__c records chronologically as they occur. The borrower watches their application progress through underwriting in real time. When no events exist yet, a pending empty state reassures the borrower that work is happening — a single amber heartbeat pulse, not a spinner or a bare empty timeline (which reads as abandonment).

### Props (@api)
```javascript
@api events = [];
// Array of { id: String, label: String, timestamp: String }
// Newest-last, rendered chronologically top-to-bottom.
// Example: [
//   { id: 'evt-1', label: 'Application received', timestamp: 'Jun 5, 2:14 PM' },
//   { id: 'evt-2', label: 'Income verified', timestamp: 'Jun 5, 3:02 PM' }
// ]
```

### Events (CustomEvent)
None. This component is display-only. The parent (Flow or Experience page) is responsible for populating the `events` array via Platform Events or polling.

### Animation / Interaction
- **Pending state (no events):** A single amber dot (`16px`, `border-radius: 999px`) pulses via a CSS `heartbeat` keyframe animation (1.6s ease-in-out infinite). Scale oscillates between `1.0` and `1.5`, opacity between `1.0` and `0.45`. This is the only motion on the screen.
- **Timeline state (events present):** Static vertical timeline. Each event is a flex row: amber dot (11px) + label + timestamp. A 1px vertical connector line (`rgba(255,255,255,0.18)`) joins consecutive dots, omitted on the last event.
- The amber accent bar (4px) sits at the bottom of every state.

### Accessibility
- Pending message uses `aria-live="polite"` so screen readers announce the waiting status without interrupting.
- Pulse dot is `aria-hidden="true"` (decorative).
- Timeline dots are `aria-hidden="true"` (decorative; event text carries the meaning).
- Timeline rendered as `<ul>` / `<li>` for correct list semantics.
- Heartbeat animation is fully disabled under `@media (prefers-reduced-motion: reduce)`.

### Mobile Behavior
- Full viewport height via `min-height: 100dvh`.
- Flexbox column layout, content centered vertically in the `.body` region.
- Padding: 32px vertical, 24px horizontal.
- Pending message constrained to `max-width: 28ch` and center-aligned.

### States
| State | Condition | Rendering |
|-------|-----------|-----------|
| Pending | `events` is empty or not an array | Centered amber heartbeat pulse + "Your file is under review. This timeline updates in real time." |
| Active | `events` has one or more entries | Vertical timeline, newest event at the bottom, amber dot per event, connector lines between events |

### Copy (locked)
- Pending line: "Your file is under review. This timeline updates in real time."

---

## Component Specification: `c-outcome-view`

### Purpose
Decision verdict screen (Screen 6). Displays the final mortgage decision outcome with appropriate semantic color, contextual actions, and regulatory compliance links. Brand law is strictly enforced: green owns the approved screen (amber never decorates approval), the word "denied" is never used, and the amber accent bar persists on every outcome state — the receipt exists regardless of the answer.

### Props (@api)
```javascript
@api outcome;          // String: APPROVED | APPROVED_WITH_CONDITIONS | PENDING_REVIEW | HARD_DECLINED
@api amount;           // Number: approved loan amount (displayed on APPROVED states)
@api rate;             // Number: illustrative rate percentage (optional, displayed on APPROVED states)
@api declineReason;    // String: from Rule_Explanation__c (displayed on HARD_DECLINED)
@api decisionEventId;  // String: Decision_Event__c Id — when present, receipt and notice links appear
```

### Events (CustomEvent)
```javascript
// Fired on APPROVED / APPROVED_WITH_CONDITIONS — borrower wants to schedule a call
this.dispatchEvent(new CustomEvent('schedulecall', { bubbles: true, composed: true }));

// Fired on HARD_DECLINED — borrower wants to see next steps
this.dispatchEvent(new CustomEvent('nextsteps', { bubbles: true, composed: true }));

// Fired on any outcome when decisionEventId is present — opens receipt PDF
// at /apex/DecisionReceipt?id={decisionEventId}
this.dispatchEvent(new CustomEvent('viewreceipt', {
    bubbles: true,
    composed: true,
    detail: { decisionEventId: this.decisionEventId }
}));

// Fired on HARD_DECLINED when decisionEventId is present — opens formal
// ECOA / Reg B notice of action taken at /apex/AdverseActionNotice?id={decisionEventId}
this.dispatchEvent(new CustomEvent('viewnotice', {
    bubbles: true,
    composed: true,
    detail: { decisionEventId: this.decisionEventId }
}));
```

### Animation / Interaction
- No motion on this screen. Static composition centered vertically.
- Semantic status chip rendered at the top of the body, followed by the verdict headline.
- Approved amount formatted via `Intl.NumberFormat` (USD, no decimals).
- CTA buttons use amber background with indigo text (action color, not celebration).
- Receipt and notice links are quiet: transparent background, white text, 1px amber underline. Offered, never shouted.
- The amber accent bar (4px) is present in every state, including declined.

### Accessibility
- Verdict headline rendered as `<h1>` for document outline.
- All buttons use `type="button"` — keyboard-focusable by default.
- Focus-visible ring: 2px solid white with 2px offset on all interactive elements.
- Color is never the sole indicator — each outcome state has a distinct chip label text ("Approved", "Approved with conditions", "In review", "Not approved") alongside its semantic color.

### Mobile Behavior
- Full viewport height via `min-height: 100dvh`.
- Flexbox column layout, content centered both vertically and horizontally, text center-aligned.
- Padding: 32px vertical, 24px horizontal.
- Verdict headline constrained to `max-width: 20ch`. Decline reason constrained to `max-width: 34ch`. Supporting text constrained to `max-width: 32ch`.
- Gap between elements: 18px.

### States
| State | Chip BG | Chip Text | Verdict Headline | Body Content |
|-------|---------|-----------|------------------|--------------|
| APPROVED | `#16734a` (green) | white | "You're approved." | Formatted amount, optional rate, "Schedule a call" CTA |
| APPROVED_WITH_CONDITIONS | `#d4920a` (amber) | indigo ink | "You're approved." | Formatted amount, optional rate, conditions note, "Schedule a call" CTA |
| PENDING_REVIEW | `#345182` (blue) | white | "Your application is under review." | Supporting message about specialist review + email notification |
| HARD_DECLINED | `#8a3324` (restrained rust) | white | "We weren't able to approve this application at this time." | Specific decline reason, forward-path message, "See next steps" CTA, optional adverse-action notice link |

### Receipt and Notice Links
- **Receipt link:** Shown on any outcome when `decisionEventId` is present. Label: "View your decision receipt". The receipt exists regardless of the answer.
- **Adverse-action notice link:** Shown only on HARD_DECLINED when `decisionEventId` is present. Label: "View your notice of action taken". This is the formal ECOA / Reg B notice of action taken (specific-reasons letter) owed to the borrower on a decline.

### Typography
- Status chip: Inter Semi-Bold, 14px, 999px radius (pill shape), 6px/14px padding.
- Verdict headline: Source Serif 4 Semi-Bold, 32px, line-height 1.1.
- Approved amount: Source Serif 4 Semi-Bold, 48px, line-height 1.05, green (`#16734a`).
- Decline reason: Inter, 16px, white, line-height 1.4.
- Supporting text: Inter, 16px, white at 60% opacity.
- CTA: Inter Semi-Bold, 16px, amber background, indigo text, 8px radius.
- Receipt/notice links: Inter Semi-Bold, 14px, white text, transparent background, 1px amber bottom border.

---

## Component Specification: `c-pre-check-result`

### Purpose
Shows soft pre-qualification result before full application.

### Apex Invocable Signature
```apex
public class PreFlightEvaluator {
    
    @InvocableMethod(label='Pre-Flight Loan Check' description='Lightweight evaluation without creating a Loan Application record')
    public static List<PreFlightResult> evaluate(List<PreFlightRequest> requests) {
        // Bulk-safe: processes list of requests
        // Loads INCOME + COLLATERAL category rules only
        // Returns eligibility band per request
    }
    
    public class PreFlightRequest {
        @InvocableVariable(required=true) public Decimal annualIncome;
        @InvocableVariable(required=true) public Decimal propertyValue;
        @InvocableVariable(required=true) public String loanType; // CONVENTIONAL, FHA, VA
    }
    
    public class PreFlightResult {
        @InvocableVariable public String eligibility;      // LIKELY_ELIGIBLE, BORDERLINE, UNLIKELY
        @InvocableVariable public Decimal estimatedDTI;
        @InvocableVariable public Decimal estimatedLTV;
        @InvocableVariable public Decimal lowEstimate;     // $ amount low end
        @InvocableVariable public Decimal highEstimate;    // $ amount high end
        @InvocableVariable public String guidance;          // Human-readable next step
    }
}
```

### Display
- Large, centered result: "$320,000 – $380,000"
- Supporting text: "Based on your income and property value, here's your estimated range."
- Color: Veridact brand green for LIKELY_ELIGIBLE, amber for BORDERLINE, neutral gray for UNLIKELY
- CTA below: "Ready to apply? Enter your email to continue."

---

## Screen Flow Summary

```
[Welcome Gate] → [Intent Capture] → [Pre-Check] → [Evidence Queue] → [Decision Room] → [Outcome]
     1 btn          3 slides          1 result       1-at-a-time         timeline         result
     no auth        no auth          email here      authenticated       authenticated    authenticated
```

Total interactions before value shown: **4** (one button + three questions).
Total interactions before account required: **5** (+ email entry after pre-check).

---

## Visual Direction (Glaser — Veridact Brand Enforcement)

> **Brand Kit v2.0.0** — migrated from Indigo/Amber (v1.0.0) to Cream/Orange (Figma Brand Kit v1.0.1) per ADR-13.

Grounded in the locked Figma brand kit (pObIwaZXpTy5cL57uzF7Ta). Core principle: **"Does this look like it belongs in a system that keeps records?"** Records imply permanence, sequence, accountability. The receipt is a hard edge — design like it.

### Core Palette (v2.0.0)
| Token | Value | Role |
|-------|-------|------|
| Cream | `#F5F0E8` | Primary background — warm, neutral, trustworthy |
| Charcoal | `#1F1E1C` | Primary text — high contrast (14.68:1 on Cream) |
| Orange | `#E25D22` | Accent, CTAs — warm action color (AA large text only on Cream: 3.18:1) |
| Approval Green | `#16734a` | Approval status — retained from v1 (5.16:1 on Cream ✅) |
| Charcoal muted | `rgba(31,30,28,0.5)` | Secondary text |
| Display font | Outfit Bold | Headlines, tagline, verdict (replaces Source Serif 4) |
| Body font | Inter | Everything else (unchanged) |

### The Orange Accent Bar (signature)
- 4px orange bar at the **bottom of every screen, every state** — including declined Outcome.
- Always a hard line. Never a glow, never a shadow, never a gradient.
- "The brand doesn't apologize for the decision. The receipt exists regardless."

### Semantic Decision Colors — Chips, Not Text
WCAG-verified against Cream `#F5F0E8` background. Chip/badge backgrounds with paired text:
| State | Chip BG | Text | Ratio (text on chip) | Ratio (chip on Cream) |
|-------|---------|------|---------------------|----------------------|
| Approved | `#16734a` | white | 5.86:1 ✅ | 5.16:1 ✅ |
| Approved w/ Conditions | `#E25D22` | **charcoal** | 4.62:1 ✅ | 3.18:1 (large only) |
| Pending Review | `#345182` | white | 7.94:1 ✅ | 7.00:1 ✅ |
| Declined | `#8a3324` (restrained rust) | white | 8.14:1 ✅ | 7.18:1 ✅ |

### Orange Discipline
- Orange = "in process, act here." It belongs on CTAs and the accent bar **only**.
- **Never** use orange as decoration on the Approved Outcome screen — green (`#16734a`) owns that screen. Orange bleeding into approval contaminates the semantic system.
- Orange text on Cream background: **large text only** (≥18pt or ≥14pt bold). Never for body text.

### Typography Boundary (hard constraint)
- **Outfit Bold** = display only: tagline, screen headline, Outcome verdict. Never below ~28px. Never in form labels.
- **Inter** carries everything else: body, labels, orientation text, errors.

### Motion Vocabulary
- Intent Capture: questions enter from **right**, exit **left** (forward through process). Going back reverses. Motion reinforces linearity — the sequence of a record.
- Honor `prefers-reduced-motion` (token already set to 0s).

### Decision Room — Pending Empty State
- Never show a bare empty timeline (reads as abandonment).
- Single **orange pulse** indicator (a heartbeat, not a spinner) — the only motion on the screen.
- One line, Inter: "Your file is under review. This timeline updates in real time."

### Evidence Queue — Orientation
- "Document 2 of 4" above the upload field, Inter small, charcoal at ~50% opacity. Not orange (orange is for action, this is orientation).

### Welcome Gate — Resolved Typographic Decision
- Headline is the **borrower-addressed** sentence "Let's find out what you qualify for" in **Inter Medium** (functional, not declarative).
- The tagline "Every decision has a receipt" appears as the **footer line** above the orange bar in Outfit Bold — the brand signature, not the CTA.

### Form Language
- No 24px radius (too playful). Use the 8px token.
- No gradient fills on primary surfaces (gradients suggest flux; the system is precise).
- Focus outlines: 2px solid Charcoal with 2px offset (was white — inverted for light background).

---

## Error States

| Scenario | Message | Action |
|----------|---------|--------|
| Upload fails | "That file didn't go through. Try again?" | Retry button |
| Extraction fails | "We couldn't read this document. Can you upload a clearer copy?" | Re-upload |
| Pre-check unavailable | "We're having trouble right now. Save your info and we'll email you." | Email capture fallback |
| Session timeout | "You were away for a bit. Your progress is saved." | Resume button |
| Network offline | "You're offline. We'll sync when you're back." | Auto-retry on reconnect |
