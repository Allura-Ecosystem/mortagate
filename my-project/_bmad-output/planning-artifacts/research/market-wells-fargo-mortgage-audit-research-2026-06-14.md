---
stepsCompleted: [research]
inputDocuments: [tavily-search-4-queries, exa-search-2-queries]
workflowType: 'research'
lastStep: 1
research_type: 'market'
research_topic: 'Wells Fargo mortgage operations, audit QC, technology stack, and Agentforce adoption in banking'
research_goals: 'Ground Veridact PRD and go-to-market with evidence-based Wells Fargo intelligence'
user_name: 'Ronin704'
date: '2026-06-14'
web_research_enabled: true
source_verification: true
---

# Market Research: Wells Fargo & Mortgage Audit QC Landscape

**Date:** 2026-06-14
**Research Type:** Market / Competitive / Technology
**Sources:** 6 parallel searches (Tavily advanced + Exa), 40+ results analyzed

---

## 1. Wells Fargo — Verified Facts

### Scale

| Metric | Value | Source |
|--------|-------|--------|
| Total assets | ~$1.9 trillion (2025), ~$2.1 trillion (2026) | WF 2025 Annual Report; Built In job posting |
| Employees | ~205,198 | AppsRunTheWorld |
| Customers | 70+ million | PMWeb case study |
| Branches | 8,500+ | PMWeb case study |
| ATMs | 13,000+ | PMWeb case study |
| Fortune ranking | #33 (2025), #34 (2024) | WF filings |
| 2025 net income | $21.3 billion | WF 2025 Annual Report |
| Q1 2026 tech spend | $2.8 billion | InfotechLead |
| Cloud adoption | 65% of core workloads | InfotechLead |
| Digital mortgage apps | 98% digital applications | WF Tech Summit PDF |

### Wells Fargo DOES Use Salesforce

**Confirmed.** Wells Fargo is a recorded user of **Salesforce Financial Services Cloud (FSC)** for Sales Automation, CRM, and Sales Engagement.

Source: AppsRunTheWorld customer database — lists Wells Fargo alongside JPMorganChase, Citigroup, and Statefarm as FSC customers.

Additional evidence: LinkedIn profile of Michele Anderson (Lead Product Manager, Digital Transformation at Wells Fargo) describes being "Product owner and administrator of the CRM Salesforce application" for Wells Fargo Commercial Distribution Finance, including "global utilization of CRM tools" across APAC, EMEA, and North America. Responsibilities include Salesforce object modeling, page layout design, workflows, rule logic, profiles, roles, and data sharing rules.

### Wells Fargo Uses nCino on Salesforce

**Confirmed.** Wells Fargo expanded nCino adoption in 2022 from commercial lending to Consumer and Small Business Banking.

> "Collaborating with nCino is expected to provide our customers with a more streamlined lending experience, reducing the sometimes tedious back and forth that sometimes occurs when applying for and obtaining a loan."

Source: nCino press release, March 2022

nCino Bank Operating System runs on the Salesforce Platform. This means Wells Fargo already has Salesforce infrastructure in lending operations.

### Wells Fargo's AI Strategy: Google Cloud, NOT Salesforce Agentforce

**This is the critical finding.**

Wells Fargo is building its agentic AI on **Google Cloud**, not Salesforce Agentforce:

- **2021:** Partnered with Google Cloud and Microsoft Azure for advanced analytics
- **2022:** Launched "**Fargo**" digital assistant, built on Google's conversational AI
- **2025:** Adopted Google **Agentspace** for custom AI agents; deployed Deep Research and NotebookLM to ~2,000 employees
- **2026:** Rolling out enterprise-wide generative AI platform for ALL employees, powered by Google Cloud
- **2026:** "**Project Apex**" — AI-driven hyper-personalized financial advice initiative

> "We've broken our strategy into a couple key focus areas. We've had a developer platform that we've been working on and building and enabling and rolling out a lot of use cases. The portion we're partnering with Google on is the employee capability."
> — Tracy Kerrins, Head of Consumer Technology and Generative AI, Wells Fargo (Money 20/20, Nov 2025)

Source: National Mortgage News / American Banker, November 2025

**Key metrics for Fargo assistant:**
- 25+ million customer interactions handled
- 70% of routine inquiries resolved without human intervention
- AI-driven "Smart Conversations" achieved 73% resolution rate for customer inquiries (KPMG report)

**Organizational structure:**
- **Bridget Engle** — SEVP, Head of Technology (from BNY, joined 2024)
- **Tracy Kerrins** — Head of Consumer Technology + new Generative AI team
- Dedicated "Home Lending Originations Technology" group (actively hiring for agentic AI roles)

Source: Wells Fargo press releases, Built In job posting

### Wells Fargo Core Banking: TCS BaNCS (FutureCore)

Wells Fargo modernized its core loan and deposit systems to **TCS BaNCS** under the "FutureCore" initiative. This is a full core replacement, not a wrapper.

Key characteristics:
- Cloud-enabled, component-based
- Real-time processing and data
- API/service-oriented architecture
- Parameter-driven (supports rapid product changes)
- One data model externalized from the core

They also use **MuleSoft** for API integration (Banking-as-a-Service platform).

Source: Wells Fargo Tech Summit 2023 presentation; MuleSoft video

### Wells Fargo Regulatory / Audit History

Wells Fargo has an **extensive** consent order history — this is directly relevant to Veridact's value proposition:

- **2011:** FRB consent order requiring enhanced audit programs for residential mortgage loan servicing, loss mitigation, and foreclosure
- **2016:** CFPB + OCC consent orders ($185M penalties) — unauthorized account openings
- **2018:** OCC compliance consent order — **terminated January 2025** (10th order closed since 2019)
- **2021:** OCC loss mitigation consent order — **terminated 2025** ("in just three and a half years")
- **5 consent orders closed since beginning of 2025**
- **10 consent orders closed since 2019**

The FRB consent order **explicitly required**:
1. Internal audit program encompassing residential mortgage loan servicing
2. Periodic review of effectiveness of ERM with respect to mortgage servicing
3. Adequate qualified staffing of the audit function for mortgage activities
4. Enhanced quarterly reporting to Board Audit and Examination Committee

> "We remain confident that we will complete the work required in our remaining consent orders."
> — Charlie Scharf, CEO (2025)

Source: Federal Reserve enforcement documents; WF Newsroom press releases; OCC enforcement actions

**Implication for Veridact:** Wells Fargo has lived under regulatory scrutiny for 15+ years on mortgage operations. They need audit tools that produce defensible, structured, regulator-ready evidence. The "Every decision has a receipt" tagline directly addresses their pain.

### Wells Fargo Home Lending — Current Hiring Signal

A current job posting for **Software Engineering Senior Manager — Home Lending Originations Technology** explicitly calls for:

> "Champion the adoption of AI and agentic systems across Originations, including: intelligent insights and anomaly detection, guided root-cause analysis and remediation, automation to reduce operational toil."

And requires:

> "Experience driving the adoption and effective use of AI code generation and agentic code development tools and delivering generative and agentic AI solutions."

Source: Built In job board (active posting, 2026)

**Implication:** Wells Fargo is actively building agentic AI into mortgage originations. They are buying this capability, not just thinking about it.

---

## 2. Mortgage QC Software — Competitive Landscape

### Established Players

| Competitor | Founded | Positioning | Key Clients | Differentiator |
|-----------|---------|-------------|-------------|----------------|
| **ACES Quality Management** | — | #1 web-based QC platform | 7 of top 10 independent mortgage lenders, 2 of top 5 commercial banks, 4 of top 5 servicers | Flexible audit technology, enterprise scale, 500% efficiency gain reported |
| **Black Knight Loan Quality Advisor** | — | AI-powered pre-funding and post-closing | Large banks and servicers | Automated risk assessment, compliance validation |
| **QC Ally (LQ Pro)** | — | Cloud-based audit management | Mid-to-large lenders | Real-time reporting, reviewer workflows |
| **MetaSource** | — | Outsourced post-close audits + QLink software | Lenders needing outsourced QC | 35-day turnaround, agency-compliant, variable cost model |
| **TENA Companies** | 1982 | Oldest in industry, SECONDLOOK software | Nationwide lenders | 40+ years, no offshore workers, all-agency coverage |
| **Encompass (ICE Mortgage Technology)** | — | QC embedded in LOS | Mortgage lenders using Encompass | Integrated with origination workflow |
| **nCino Mortgage Suite** | — | Cloud-native QC workflows on Salesforce | Banks using nCino (including WF) | Built on Salesforce platform |

### Emerging AI Players

| Competitor | Positioning | Key Claim |
|-----------|-------------|-----------|
| **TRUE.ai** | Mortgage QC automation across lifecycle | 80% reduction in manual document handling, $400/file savings, 4x productivity |
| **Alchemist Solutions** | Post-close QC automation | 50% defect reduction, 40% audit cycle time reduction |
| **Prudent AI** | AI underwriting and income calculation | Non-QM income calculation, auto-populate DU/LPA fields |
| **BeSmartee** | AI-driven digital origination with built-in QC | Error detection at origination |

### What None of Them Do (Veridact's Gap)

Based on the research, the existing QC tools focus on:
- **Pre-funding checks** — catch errors before closing
- **Post-closing audits** — verify files after closing
- **Compliance validation** — check against current agency guidelines
- **Defect tracking** — log and remediate issues

**What they don't do:**
1. **Historical policy replay** — none replay the exact rules in force at approval time vs. current rules
2. **Evidence-to-rule mapping with AI assistance** — auditors still manually match documents to rules
3. **Agentforce/AI assistant for auditors** — no tool provides a conversational AI that drafts findings and requests evidence
4. **Immutable audit receipts** — audit trails exist but are not append-only by code enforcement
5. **Exception vs. Violation distinction** — most tools track "defects" as a single category, not the nuanced Pass/Exception/Violation model

---

## 3. Agentforce Adoption in Banking — Market Reality

### Overall Numbers

- **18,500 Agentforce deals** as of October 2025 earnings call
- **6,000 in Q3 alone** vs. 4,500 in Q2 — accelerating
- **10,000+ paying Agentforce and Data 360 customers** (Dreamforce 2025)
- Financial services AI agent actions growing at **105% monthly average rate**

Source: Salesforce earnings calls; Dreamforce 2025 announcements; Vantage Point analysis

### Banking-Specific Adoption

- **RBC Wealth Management** — Agentforce deployed to 4,500 financial advisors; meeting prep from 1+ hour to < 1 minute
- **Agentforce 360 for Financial Services** — announced Dreamforce 2025 with pre-built templates for banking
- Banking use cases: loan processing, KYC, fraud detection, compliance, customer onboarding

### Honest Assessment (Vantage Point, 2026)

> "If you attended Dreamforce 2025, you'd think every financial advisor in America was already having conversations with AI agents between client meetings. The reality? We're still early — and that's not necessarily a bad thing."

> "The gap between 'deal closed' and 'deployed in production' is where firms need to focus their attention."

> "The firms struggling with AI aren't struggling with the technology — they're struggling with their data."

Source: Vantage Point — "The State of AI and Agentforce in Financial Services: A Reality Check for 2026"

### Deployment Timeline for Financial Services

**3-6 months** added to deployment timelines for financial institutions due to security audits and compliance validation.

Source: Oliv.ai Agentforce use case analysis

---

## 4. Implications for Veridact

### The Wells Fargo Paradox

Wells Fargo is the **ideal buyer profile** for Veridact:
- Under 15+ years of consent order scrutiny on mortgage operations
- Actively hiring for agentic AI in Home Lending Originations
- Already on Salesforce FSC + nCino
- Spending $2.8B/quarter on technology
- Needs audit tools that produce regulator-ready evidence

But there's a complication: **they're building their AI on Google Cloud, not Salesforce Agentforce.**

### Three Positioning Options

**Option A: Salesforce-native (current plan)**
- Veridact runs on Salesforce + Agentforce
- Fits WF's existing Salesforce/nCino footprint for lending
- But competes with their Google Cloud AI investment for the "agent" layer
- Best for: banks that are Salesforce-committed for lending

**Option B: Platform-agnostic with Salesforce option**
- Core audit engine (React + Allura) is platform-independent
- Salesforce + Agentforce is one deployment option
- Google Cloud + Vertex AI is another
- Best for: maximizing addressable market, including WF

**Option C: Complement, don't compete**
- Position Veridact as a **Salesforce-native QC workflow tool** (not an AI platform)
- Agentforce handles the assistant layer for Salesforce-native banks
- For WF, the React cockpit + Allura reasoning could connect to their Google AI instead
- Best for: avoiding the "we're replacing your AI strategy" objection

### Competitive Positioning

Veridact's moat vs. ACES, MetaSource, TENA, and TRUE.ai:

| Capability | ACES | TRUE.ai | Veridact |
|-----------|------|---------|----------|
| Post-close audit workflows | Yes | Yes | Yes |
| Historical policy replay | No | No | **Yes** |
| Evidence-to-rule AI mapping | No | Partial (doc classification) | **Yes** |
| Conversational AI assistant | No | No | **Yes (Agentforce/Allura)** |
| Immutable audit receipt (code-enforced) | No (audit trail, not immutable) | No | **Yes** |
| Exception vs. Violation model | No (single "defect" category) | No | **Yes** |
| Salesforce-native | No | No | **Yes** |

### Pricing Signal

No direct pricing found for ACES or competitors, but MetaSource uses a **variable cost model** for outsourced audits. TENA's SECONDLOOK is licensed software. The market supports both SaaS and per-audit pricing.

---

## 5. Source Index

| # | Source | URL | Date | Confidence |
|---|--------|-----|------|------------|
| 1 | Wells Fargo 2025 Annual Report | wellsfargo.com/assets/pdf/about/investor-relations/annual-reports/2025-annual-report.pdf | 2025 | High |
| 2 | AppsRunTheWorld — Salesforce FSC Customers | appsruntheworld.com/customers-database/products/view/salesforce-financial-services-cloud | 2025 | High |
| 3 | nCino — Wells Fargo Expansion | ncino.com/news/wells-fargo-adoption-ncino | 2022-03 | High |
| 4 | National Mortgage News — WF Agentic AI | nationalmortgagenews.com/news/how-wells-fargo-is-building-agentic-ai | 2025-11 | High |
| 5 | InfotechLead — WF AI/Cloud 2026 | infotechlead.com/cio/wells-fargo-bolsters-ai-driven-digital-transformation | 2026-04 | High |
| 6 | Wells Fargo Tech Summit — FutureCore | s203.q4cdn.com/.../Wells-Fargo-Tech-Summit.pdf | 2023 | High |
| 7 | PMWeb — WF Integrations Award | pmweb.com/news/bridging-systems-at-scale-wells-fargo | 2025-06 | High |
| 8 | Federal Reserve — WF Consent Order | federalreserve.gov/newsevents/press/enforcement/wellsfargo-plan-sect5-audit.pdf | 2011+ | High |
| 9 | WF Newsroom — OCC Order Terminations | newsroom.wf.com (multiple) | 2025 | High |
| 10 | Built In — WF Home Lending AI Hiring | builtin.com/job/software-engineering-senior-manager/8798975 | 2026 | High |
| 11 | Google Cloud — WF Case Study | cloud.google.com/customers/wellsfargo | 2025 | High |
| 12 | KPMG — Mortgage Platform Modernization | kpmg.com/kpmg-us/content/dam/kpmg/pdf/2026/mortgage-platform-modernization.pdf | 2026 | High |
| 13 | ZipDo — Mortgage QC Software Ranking | zipdo.co/best/mortgage-quality-control-software | 2026-03 | Medium |
| 14 | Gitnux — Mortgage QC Software | gitnux.org/best/mortgage-qc-software | 2026-03 | Medium |
| 15 | Vantage Point — Agentforce in FinServ Reality Check | vantagepoint.io/blog/sf/state-of-ai-agentforce-financial-services-2026 | 2026 | High |
| 16 | Salesforce Ben — Agentforce FinServ Guide | salesforceben.com/resource/the-ultimate-guide-to-agentforce-adoption-in-financial-services | 2025 | Medium |
| 17 | Zennify — Dreamforce 2025 FinServ | zennify.com/articles/top-5-dreamforce-2025-announcements-for-financial-services | 2025 | High |
| 18 | ACES Quality Management | acesquality.com | 2026 | High |
| 19 | TENA Companies | tenaco.com | 2026 | High |
| 20 | MetaSource — Post-Close QC | metasource.com/solutions/mortgage-qc/post-close-qc-audits | 2026 | High |
| 21 | TRUE.ai — Mortgage QC Automation | true.ai/mortgage-qc-automation | 2026-04 | High |
| 22 | Alchemist Solutions — Modernizing QC | connect.alchemistsolutions.io/blog/modernizing-mortgage-qc | 2025-05 | High |
| 23 | Michele Anderson LinkedIn — WF Salesforce usage | linkedin.com/in/michele-anderson-5407519 | Current | Medium |
