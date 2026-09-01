import type { PluginInput, Hooks, PluginModule } from "@opencode-ai/plugin";
import { tool } from "@opencode-ai/plugin";
import { z } from "zod";

/**
 * Mortgate OpenWork plugin — BMad-driven onboarding + menu for the
 * Mortgage Approval Engine (current product: Mortgate Evidence Review).
 *
 * This plugin exposes an operator-facing surface (menu + onboarding) for the
 * four Cowork product skills, plus BMad build/validation entry points. It
 * deliberately carries NO agents of its own — the product surface stays
 * "bare" per the product brief; this just gives the OpenWork operator a
 * discoverable, BMad-routed way to work the module.
 */

const PRODUCT_SKILLS = [
  {
    id: "mortgage-case-onboarding",
    path: "microsoft-cowork/appPackage/skills/mortgage-case-onboarding",
    label: "Mortgage Case Onboarding",
    desc: "Set up an evidence-review task from an employee's request.",
  },
  {
    id: "loan-file-evidence-review",
    path: "microsoft-cowork/appPackage/skills/loan-file-evidence-review",
    label: "Loan File Evidence Review",
    desc: "Inventory uploaded documents; identify missing, ambiguous, and conflicting evidence.",
  },
  {
    id: "policy-replay-review",
    path: "microsoft-cowork/appPackage/skills/policy-replay-review",
    label: "Policy Replay Review",
    desc: "Compare a supplied deterministic policy replay against the evidence.",
  },
  {
    id: "audit-packet-draft",
    path: "microsoft-cowork/appPackage/skills/audit-packet-draft",
    label: "Audit Packet Draft",
    desc: "Assemble an audit evidence packet for a human reviewer.",
  },
] as const;

const BMAD_ENTRY_POINTS = [
  { id: "bmad-dev-story", label: "Story Build (BMad)", desc: "bmad-dev-story — implement the next story from a spec." },
  { id: "bmad-validate-prd", label: "Validate PRD (BMad)", desc: "bmad-validate-prd / bmad-check-implementation-readiness." },
  { id: "bmad-agent-builder", label: "Skill Builder (BMad)", desc: "bmad-agent-builder — analyze/refine a skill." },
  { id: "plugin-builder", label: "Plugin Build (OpenCode)", desc: "plugin-builder — package the cross-runtime plugin." },
  { id: "command-creator", label: "Command/Menu (OpenCode)", desc: "command-creator — add OpenCode custom commands." },
] as const;

const SAFETY_NOTE =
  "Evidence-review workspace only. Reaches no decision, writes to no system of record. Every output is a draft for a human reviewer.";

/**
 * Allura Brain integration for the Mortgate plugin.
 *
 * DESIGN (per governing decision): Allura is the memory / governance layer,
 * NOT the audit. The audit itself runs in the four Cowork product skills.
 * The plugin is the operator-facing surface and is the ONLY place Allura is
 * wired. The employee-facing skills stay Allura-free (ADR-34).
 *
 * All memory operations MUST use group_id "allura-mortgage" with an explicit,
 * per-agent user_id suffix. Writes are ALWAYS an explicit operator action —
 * never an automatic side-effect of a skill run (append-only, human-signed).
 *
 * IMPORTANT LIMITATION (verified against the OpenCode SDK): the MCP namespace
 * exposes only status/add/connect/disconnect/auth — there is NO direct "call
 * MCP tool" method. So `allura-brain_memory_*` tools are invoked by the agent
 * in its normal reasoning loop, not from inside this plugin's execute()
 * handler. These plugin tools therefore emit a structured, machine-checkable
 * directive that the agent follows to invoke the governed memory tool. When no
 * reachable Allura Brain is present, they fail loudly instead of pretending.
 */

const ALLURA_GROUP_ID = "allura-mortgage";
const ALLURA_MCP_NAME = "allura-brain";
const ALLURA_MCP_URL =
  (globalThis as { process?: { env?: Record<string, string | undefined> } }).process?.env?.
    ALLURA_BRAIN_MCP_URL ?? "https://mcp.faithmeats.org/mcp";
// Token headers mirror the global opencode config so the plugin's own
// registration is self-sufficient and authenticated when the env tokens are
// present in the runtime. {env:...} placeholders are resolved by OpenCode.
const ALLURA_MCP_HEADERS = {
  Authorization: "Bearer {env:ALLURA_MCP_TROY_DESKTOP_TOKEN}",
  "CF-Access-Client-Id": "{env:ALLURA_CF_ACCESS_CLIENT_ID}",
  "CF-Access-Client-Secret": "{env:ALLURA_CF_ACCESS_CLIENT_SECRET}",
};

const ALLURA_PROBE_NOTE =
  "STATUS: Allura Brain connection is NOT verified from this environment (no MCP server handle / tokens). " +
  "This directive is correct but UNVERIFIED end-to-end. It will only take effect where the `allura-brain` " +
  "MCP server is reachable and its memory_* tools are present. Do not claim a receipt was persisted until " +
  "it is retrieved back from a live Brain.";

/** Build a stable per-persona user_id suffix for Mortgate operators. */
function alluraUserId(role: string): string {
  return `mortgate-plugin-${role || "operator"}`;
}

/** Helper: prefix a directive with the governed Allura call the agent must make. */
function memoryDirective(opts: {
  action: string;
  payload: string;
  role: string;
}): string {
  const userId = alluraUserId(opts.role);
  return [
    "## Allura Brain memory directive (agent must execute)",
    "",
    `Call the governed \`allura-brain_memory_${opts.action}\` MCP tool with EXACTLY:`,
    "",
    "```json",
    JSON.stringify(
      {
        group_id: ALLURA_GROUP_ID,
        user_id: userId,
        ...(opts.payload ? JSON.parse(opts.payload) : {}),
      },
      null,
      2,
    ),
    "```",
    "",
    "Rules:",
    `- group_id MUST be "${ALLURA_GROUP_ID}" (never a legacy tenant).`,
    "- This is an explicit, human-authorized operation. Do NOT auto-fire it on every skill run.",
    `- ${ALLURA_PROBE_NOTE}`,
  ].join("\n");
}

async function skillExists(s: string, $: PluginInput["$"]): Promise<boolean> {
  try {
    const r = await $`test -f ${s} && echo yes`;
    return r.stdout.toString().trim() === "yes";
  } catch {
    return false;
  }
}

export const MortgatePlugin = async (input: PluginInput): Promise<Hooks> => {
  const { $, directory } = input;

  const menuText = await (async () => {
    const lines: string[] = [];
    for (const s of PRODUCT_SKILLS) {
      const ok = await skillExists(`${s.path}/SKILL.md`, $);
      const full = `${directory}/${s.path}/SKILL.md`;
      lines.push(`  • ${ok ? "✓" : "!"} ${s.label} — ${s.desc}\n      ${full}`);
    }
    return lines.join("\n");
  })();

  return {
    config: async (cfg) => {
      // Ensure the governed Allura Brain MCP server is present for this
      // plugin's session so the agent can invoke allura-brain_memory_*.
      cfg.mcp = cfg.mcp ?? {};
      cfg.mcp[ALLURA_MCP_NAME] = {
        type: "remote",
        url: ALLURA_MCP_URL,
        enabled: true,
        oauth: false,
        headers: ALLURA_MCP_HEADERS,
        ...(typeof cfg.mcp[ALLURA_MCP_NAME] === "object" && cfg.mcp[ALLURA_MCP_NAME]
          ? (cfg.mcp[ALLURA_MCP_NAME] as Record<string, unknown>)
          : {}),
      };
    },
    tool: {
      mortar_menu: tool({
        description:
          "Mortgate product menu — lists the four Cowork evidence-review skills with their on-disk paths and the BMad/OpenCode build entry points. Use to orient before routing work.",
        args: {},
        async execute(_args, ctx) {
          const seen: string[] = [];
          for (const s of PRODUCT_SKILLS) {
            const ok = await skillExists(`${s.path}/SKILL.md`, $);
            if (ok) seen.push(s.id);
          }
          return {
            title: "Mortgate menu",
            output: [
              "# Mortgate — Evidence Review Product Menu",
              "",
              "**Runtime:** OpenWork/OpenCode (this repo). BMad installed; no plugin-owned agents.",
              "",
              "## Product skills (4)",
              menuText,
              "",
              `## Skill readiness\nDetected ${seen.length}/4 present on disk.`,
              "",
              "## Build / route entry points (BMad + OpenCode)",
              BMAD_ENTRY_POINTS.map((b) => `  • ${b.label} — ${b.desc}`).join("\n"),
              "",
              `## Safety\n${SAFETY_NOTE}`,
              "",
              "Next actionable step: run `/mortgate` for the menu or `/mortgate-onboard` for guided onboarding, or invoke a BMad skill directly (estories, /quick-dev).",
            ].join("\n"),
            metadata: {
              runtime: "openwork",
              skills_seen: seen,
              bmad_installed: true,
            },
          };
        },
      }),

      mortar_onboard: tool({
        description:
          "Guided onboarding for the Mortgate Evidence Review product. Takes the operator through what the module is, what the four skills do, the pilot safety boundaries, and how to start a first case.",
        args: {
          step: z
            .enum(["overview", "skills", "safety", "start"])
            .optional()
            .describe("Which onboarding stage to show. Omit for the full walkthrough."),
        },
        async execute(args, ctx) {
          const overview = [
            "# Mortgate Evidence Review — Onboarding",
            "",
            "Mortgate is an **evidence-review workspace**, not an underwriting engine. It helps a",
            "mortgage employee inventory a loan file's evidence and draft an audit packet for a human",
            "reviewer. It never decides, never writes to a system of record.",
          ].join("\n");

          const skills = [
            "## The four skills",
            ...PRODUCT_SKILLS.map((s) => `- **${s.label}** — ${s.desc} (${s.path})`),
          ].join("\n");

          const safety = [
            "## Pilot safety boundaries",
            "- No approvals, denials, or credit decisions.",
            "- No borrower messaging, no adverse-action notices.",
            "- No writes to any loan system of record.",
            "- Synthetic / nonproduction documents only during pilot.",
            SAFETY_NOTE,
          ].join("\n");

          const start = [
            "## Start a first case",
            "1. Use `mortgage-case-onboarding` to open an evidence-review task from an employee request.",
            "2. `loan-file-evidence-review` inventories what is present / missing / conflicting.",
            "3. `policy-replay-review` compares a supplied replay against the evidence.",
            "4. `audit-packet-draft` assembles the packet for a human reviewer.",
            "",
            "Tip: in OpenWork, type `/mortgate` (menu) or `/mortgate-onboard start` to jump straight here.",
          ].join("\n");

          const full = [overview, "", skills, "", safety, "", start].join("\n");

          switch (args.step) {
            case "overview":
              return { title: "Mortgate onboarding — overview", output: overview };
            case "skills":
              return { title: "Mortgate onboarding — skills", output: skills };
            case "safety":
              return { title: "Mortgate onboarding — safety", output: safety };
            case "start":
              return { title: "Mortgate onboarding — start", output: start };
            default:
              return { title: "Mortgate onboarding", output: full };
          }
        },
      }),

      mortar_memory_search: tool({
        description:
          "Allura Brain memory search for the Mortgate audit. Use BEFORE starting or continuing an evidence-review case to pull prior findings, prior decisions on the same borrower, and prior policy versions (group_id: allura-mortgage). Emits a governed memory_search directive for the agent to execute. Explicit operator action.",
        args: {
          query: z.string().describe("Natural-language search over prior Mortgate audit memory."),
          role: z
            .enum(["reviewer", "brooks", "scout"])
            .optional()
            .describe("Operator persona to attribute the user_id as. Default: reviewer."),
        },
        async execute(args, ctx) {
          return {
            title: "Mortgate — Allura memory search directive",
            output: memoryDirective({
              action: "search",
              role: args.role ?? "reviewer",
              payload: JSON.stringify({
                query: args.query,
                group_id: ALLURA_GROUP_ID,
                limit: 10,
              }),
            }),
          };
        },
      }),

      mortar_memory_log: tool({
        description:
          "Log an append-only finding event to Allura Brain for the current Mortgate audit case (group_id: allura-mortgage). Explicit operator action — NEVER auto-fires from a skill run. Records one rule-finding classification (Pass / Exception / Violation) mapped to evidence. Emits a governed memory_add directive for the agent to execute.",
        args: {
          caseId: z.string().describe("Identifier for the audit case (e.g. conflict-pair)."),
          ruleId: z.string().describe("Rule identifier from the replay (e.g. rule-creditscore-min)."),
          classification: z
            .enum(["PASS", "EXCEPTION", "VIOLATION"])
            .describe("Rule-finding classification against evidence."),
          evidenceRefs: z
            .array(z.string())
            .optional()
            .describe("Evidence item references (doc type + id) that support the finding."),
          note: z.string().optional().describe("Optional human note on the finding."),
          role: z
            .enum(["reviewer", "brooks", "scout"])
            .optional()
            .describe("Operator persona to attribute the user_id as. Default: reviewer."),
        },
        async execute(args, ctx) {
          return {
            title: "Mortgate — Allura finding log directive",
            output: memoryDirective({
              action: "add",
              role: args.role ?? "reviewer",
              payload: JSON.stringify({
                content: [
                  `Mortgate audit finding — case=${args.caseId}`,
                  `rule=${args.ruleId}`,
                  `classification=${args.classification}`,
                  args.evidenceRefs?.length
                    ? `evidence=${args.evidenceRefs.join(",")}`
                    : "evidence=none",
                  args.note ? `note=${args.note}` : "",
                ]
                  .filter(Boolean)
                  .join("\n"),
                metadata: {
                  kind: "mortgate-finding",
                  caseId: args.caseId,
                  ruleId: args.ruleId,
                  classification: args.classification,
                  evidenceRefs: args.evidenceRefs ?? [],
                },
              }),
            }),
          };
        },
      }),

      mortar_receipt_sign: tool({
        description:
          "Sign an immutable, append-only audit receipt for a finished Mortgate case and promote it to canonical status in Allura Brain (group_id: allura-mortgage). This is the closing human sign-off step — caller must attest that the case was reviewed. Emits a governed memory_add + memory_promote directive sequence for the agent to execute. Explicit operator action.",
        args: {
          caseId: z.string().describe("Identifier for the audit case (e.g. conflict-pair)."),
          reviewer: z.string().describe("Human reviewer attestation name/initials."),
          summary: z.string().describe("One-line outcome summary for the receipt."),
          classificationCounts: z
            .object({
              pass: z.number().optional(),
              exception: z.number().optional(),
              violation: z.number().optional(),
            })
            .optional()
            .describe("Rule-finding classification totals, if known."),
          role: z
            .enum(["reviewer", "brooks", "scout"])
            .optional()
            .describe("Operator persona to attribute the user_id as. Default: reviewer."),
        },
        async execute(args, ctx) {
          return {
            title: "Mortgate — Allura receipt sign directive",
            output: [
              "## Signed audit receipt (append-only, canonical)",
              "",
              `**Case:** ${args.caseId}`,
              `**Reviewer attestation:** ${args.reviewer}`,
              `**Summary:** ${args.summary}`,
              args.classificationCounts
                ? `**Totals:** pass=${args.classificationCounts.pass ?? 0}, exception=${args.classificationCounts.exception ?? 0}, violation=${args.classificationCounts.violation ?? 0}`
                : "",
              "",
              "## Allura Brain directive (agent must execute, in order)",
              "",
              "1. **Log the signed receipt** — Call the governed `allura-brain_memory_add` MCP tool with EXACTLY:",
              "```json",
              JSON.stringify(
                {
                  group_id: ALLURA_GROUP_ID,
                  user_id: alluraUserId(args.role ?? "reviewer"),
                  content: `Signed audit receipt — ${args.caseId} — ${args.summary} — attested by ${args.reviewer}`,
                  metadata: {
                    kind: "mortgate-receipt",
                    caseId: args.caseId,
                    reviewer: args.reviewer,
                    summary: args.summary,
                    totals: args.classificationCounts ?? {},
                    signed: true,
                  },
                },
                null,
                2,
              ),
              "```",
              "",
              "2. **Promote to canonical (HITL)** — Call the governed `allura-brain_memory_promote` MCP tool on the receipt just logged so it becomes a retrievable canonical audit record.",
              "",
              "Rules:",
              `- group_id MUST be "${ALLURA_GROUP_ID}".`,
              "- Append-only: do not overwrite or mutate an existing receipt; add a new versioned record.",
              "- This closes the case. Only the human reviewer sign-off triggers it (never automatic).",
              `- ${ALLURA_PROBE_NOTE}`,
            ].join("\n"),
          };
        },
      }),
    },
  };
};

const module: PluginModule = {
  id: "mortgate",
  server: MortgatePlugin,
};

export default module;
