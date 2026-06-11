---
name: lwc-craft
description: "LWC component craft for Mortgate. One-thing-per-screen, mobile-first (375px), no Salesforce chrome, three-state model (Empty/Active/Decision), wire/imperative Apex patterns, jest tests. Load when building or reviewing LWC components for the Mortgage borrower portal."
---

# lwc-craft — LWC Component Craft for Mortgate

This skill is the standard for all **Lightning Web Components** in the **Mortgage Approval Engine** borrower portal.

> **AI-Assisted Documentation**
> Portions of this skill were drafted with AI assistance.

---

## When to Use This Skill

Load this skill whenever:

- Building a new LWC for the borrower portal
- Reviewing an LWC for simplicity and accessibility
- Wiring `@wire` or imperative Apex from a component
- Designing a new screen in the 6-screen borrower journey
- Auditing a component for "one thing per screen" compliance

---

## Design Principles (from BLUEPRINT B2)

1. **Mobile-first** — 375px is the primary design surface. Desktop is the scale-up.
2. **One thing per screen** — Every portal view renders exactly one question, one status, or one action.
3. **Three states, not screens** — Empty (capture intent) → Active (feed + status) → Decision (outcome).
4. **No Salesforce chrome** — Experience Cloud skinned completely. Zero platform branding in borrower view.
5. **Slide-in/slide-out** — Animated transitions, not a form. A conversation.

---

## Component Naming

- Prefix: `c-` (e.g., `c-welcome-gate`, `c-intent-capture`)
- Kebab-case for component folder
- PascalCase for JS class (`welcomeGate` → `class WelcomeGate extends LightningElement`)

```
force-app/main/default/lwc/
├── welcomeGate/
│   ├── welcomeGate.html
│   ├── welcomeGate.js
│   ├── welcomeGate.js-meta.xml
│   ├── welcomeGate.css
│   ├── __tests__/
│   │   └── welcomeGate.test.js
│   └── ...
```

---

## LWC Skeleton

### welcomeGate.html

```html
<template>
  <div class="welcome-gate">
    <h1 class="welcome-gate__title">Let's find out what you qualify for.</h1>
    <p class="welcome-gate__subtitle">Takes 8 minutes.</p>
    <lightning-button
      variant="brand"
      label="Get Started"
      onclick={handleGetStarted}
      class="welcome-gate__cta"
    ></lightning-button>
  </div>
</template>
```

### welcomeGate.js

```javascript
import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class WelcomeGate extends NavigationMixin(LightningElement) {
  handleGetStarted() {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name: 'Intent_Capture__c' }
    });
  }
}
```

### welcomeGate.js-meta.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
  <apiVersion>62.0</apiVersion>
  <isExposed>true</isExposed>
  <masterLabel>Welcome Gate</masterLabel>
  <description>One-thing-per-screen welcome screen. Mobile-first.</description>
  <targets>
    <target>lightningCommunity__Page</target>
    <target>lightningCommunity__Default</target>
  </targets>
  <targetConfigs>
    <targetConfig targets="lightningCommunity__Page">
      <property name="title" type="String" default="Welcome" />
    </targetConfig>
  </targetConfigs>
</LightningComponentBundle>
```

---

## Apex Wiring Patterns

### @wire (reactive, read-only)

```javascript
import { wire } from 'lwc';
import getApplicationStatus from '@salesforce/apex/ApplicationController.getApplicationStatus';

export default class ApplicationStatus extends LightningElement {
  @wire(getApplicationStatus, { applicationId: '$applicationId' })
  applicationStatus;

  get status() {
    return this.applicationStatus.data?.status ?? 'Loading...';
  }
}
```

### Imperative (write actions)

```javascript
import submitApplication from '@salesforce/apex/ApplicationController.submitApplication';

async function handleSubmit() {
  try {
    this.isLoading = true;
    const result = await submitApplication({ applicationId: this.applicationId });
    this.dispatchEvent(new CustomEvent('submitted', { detail: result }));
  } catch (error) {
    this.error = this.normalizeError(error);
  } finally {
    this.isLoading = false;
  }
}

normalizeError(error) {
  if (Array.isArray(error.body)) {
    return error.body.map(e => e.message).join(', ');
  }
  return error.body?.message ?? 'Unknown error';
}
```

---

## Three-State Pattern (Empty → Active → Decision)

```javascript
import { LightningElement, wire } from 'lwc';
import getApplication from '@salesforce/apex/ApplicationController.getApplication';

export default class ApplicationState extends LightningElement {
  @wire(getApplication, { applicationId: '$applicationId' })
  application;

  get viewState() {
    const app = this.application.data;
    if (!app) return 'loading';
    if (!app.Submitted_At__c) return 'empty';      // Empty (capture intent)
    if (!app.Decision_Date__c) return 'active';    // Active (feed + status)
    return 'decision';                              // Decision (outcome)
  }

  get showIntentCapture() { return this.viewState === 'empty'; }
  get showActiveStatus() { return this.viewState === 'active'; }
  get showDecision() { return this.viewState === 'decision'; }
}
```

```html
<template>
  <template lwc:if={showIntentCapture}>
    <c-intent-capture application-id={applicationId}></c-intent-capture>
  </template>
  <template lwc:if={showActiveStatus}>
    <c-application-status application-id={applicationId}></c-application-status>
  </template>
  <template lwc:if={showDecision}>
    <c-decision-outcome application-id={applicationId}></c-decision-outcome>
  </template>
</template>
```

---

## Mobile-First CSS

```css
.welcome-gate {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 1.5rem;
  /* 375px primary surface */
}

.welcome-gate__title {
  font-size: 1.5rem;
  font-weight: 600;
  text-align: center;
  margin: 0 0 0.5rem 0;
}

.welcome-gate__cta {
  width: 100%;
  max-width: 320px;
  margin-top: 2rem;
}

/* Desktop scale-up */
@media (min-width: 768px) {
  .welcome-gate__title { font-size: 2rem; }
}
```

---

## Jest Tests (mandatory)

```javascript
// __tests__/welcomeGate.test.js
import { createElement } from 'lwc';
import WelcomeGate from 'c/welcomeGate';

describe('c-welcome-gate', () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it('renders title and CTA', () => {
    const element = createElement('c-welcome-gate', { is: WelcomeGate });
    document.body.appendChild(element);

    const title = element.shadowRoot.querySelector('.welcome-gate__title');
    expect(title.textContent).toBe("Let's find out what you qualify for.");
  });

  it('navigates to intent capture on CTA click', () => {
    const element = createElement('c-welcome-gate', { is: WelcomeGate });
    document.body.appendChild(element);

    const cta = element.shadowRoot.querySelector('lightning-button');
    cta.click();

    // Assert NavigationMixin.Navigate was called
    // (Requires NavigationMixin mock)
  });
});
```

---

## No Salesforce Chrome (Experience Cloud)

- Hide global header: use `lightningCommunity__Page` target with custom layout
- Use `lightning-button` and `lightning-input` (styled via SLDS, not platform chrome)
- Set community theme to a custom brand
- Strip utility bar in builder

---

## Accessibility (WCAG 2.1 AA)

- All interactive elements have `aria-label` or visible label
- Color contrast >= 4.5:1
- Focus indicators visible
- Keyboard navigation: Tab order is logical
- Screen reader: Use `lightning-formatted-*` for semantic markup

---

## Anti-Patterns

- ❌ Putting a 12-field form on one screen
- ❌ Showing Salesforce header / utility bar to borrowers
- ❌ Using `lightning-card` for the entire screen
- ❌ Synchronous `@wire` for write actions
- ❌ `console.log` in production
- ❌ Hard-coded user IDs

---

## Output to Brain

```javascript
allura-brain_memory_add({
  group_id: "allura-mortgage",
  user_id: "pike-interface-review-mortgage",
  content: "LWC_REVIEW: {component}, {verdict: pass|simplify|veto}, {reason}",
  metadata: { source: "lwc-review", agent_id: "pike-interface-review-mortgate", event_type: "LWC_REVIEW" }
})
```
