<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# Definition of Done — the truth ladder

A screen is NOT "done" because the server returned HTML. Climb the ladder and
report the highest level actually proven. Never report a level you did not verify.

| Level | Claim | Evidence required |
|-------|-------|-------------------|
| 1 | Server responds | route returns 200, or redirects correctly |
| 2 | HTML has content | expected real text present in the response body |
| 3 | DOM / a11y tree exists | accessibility snapshot shows the expected roles/labels |
| 4 | CSS loads | stylesheet bundle returns non-empty CSS with the design tokens |
| 5 | Browser paints | a REAL browser screenshot renders the screen correctly |
| 6 | Matches Figma | screenshot compared against the Figma node it was built from |
| 7 | Interaction works | clicks/filters/forms behave; state changes happen |
| 8 | UX accepted | persona panel + Brooks + Durham gates pass |

## Rules

- **Levels 1–4 are STRUCTURAL verification only.** A score based solely on
  HTTP 200 / source review / DOM snapshot must be labeled a **"structural
  score," not a final UX score.** Do not say "done" off structural evidence.
- **Level 5+ is VISUAL verification.** It requires a real browser paint, not
  the Claude_Preview pane (it wedges and times out here). Use the
  **Claude_in_Chrome** tools: `tabs_context_mcp` → `navigate` →
  `computer{action:screenshot}`. Dev server runs on **port 3223**
  (`npm run dev`).
- For EVERY routed screen (Audit Queue, Case Review, Findings, Receipts,
  Analytics, Policy Versions, Admin) the visual QA gate is:
  open route → screenshot → confirm CSS paints → compare to Figma →
  check console errors → confirm desktop AND mobile → THEN mark
  "visually verified."
- Browser-extension-injected attributes on `<body>` (Grammarly:
  `data-gr-*`) cause a benign hydration warning; handled via
  `suppressHydrationWarning` on `<body>`. A clean console means no OTHER
  errors.
