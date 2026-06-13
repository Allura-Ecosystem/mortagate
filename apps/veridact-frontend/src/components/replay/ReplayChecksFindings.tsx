import Link from "next/link";
import type { CheckStatus, ReplayCheck, EvidenceItem, Finding } from "@/lib/types";
import { GlossedText, Term } from "../Term";
import { glossFor } from "@/lib/glossary";
import { CheckLegend } from "../Legend";
import { EVIDENCE_STATUS_CLASSES } from "../EvidencePanel";

const statusClasses: Record<CheckStatus, string> = {
  Pass: "bg-chip-green-bg text-chip-green-fg",
  Exception: "bg-chip-amber-bg text-chip-amber-fg",
  Unverifiable: "bg-chip-amber-bg text-chip-amber-fg",
  Violation: "bg-chip-red-bg text-chip-red-fg",
};

// Severity-first order for the at-a-glance rollup, with singular/plural labels
// so the one-line summary reads naturally (Hank: "what is the state of this
// screen at a glance"). Worst news first.
const ROLLUP_ORDER: CheckStatus[] = ["Violation", "Exception", "Unverifiable", "Pass"];
const STATUS_LABELS: Record<CheckStatus, { one: string; many: string }> = {
  Violation: { one: "Violation", many: "Violations" },
  Exception: { one: "Exception", many: "Exceptions" },
  Unverifiable: { one: "Unverifiable", many: "Unverifiable" },
  Pass: { one: "Pass", many: "Passes" },
};

export function ReplayChecksFindings({
  checks,
  evidence,
  findings,
  onRequestEvidence,
  onCreateFinding,
  onReadyForSignoff,
  canSignoff,
  roleCanSignoff,
  signoffBlockers,
}: {
  checks: ReplayCheck[];
  // The evidence items this case carries, so each check can name the document(s)
  // it leans on — making the rule → evidence → finding chain explicit (Hank).
  evidence: EvidenceItem[];
  // Findings already recorded on this case, so a flagged check's "see finding"
  // pointer can be a real link to the write-up rather than dead text (Leo).
  findings: Finding[];
  onRequestEvidence: () => void;
  onCreateFinding: () => void;
  onReadyForSignoff: () => void;
  canSignoff: boolean;
  // Whether the signed-in role may make this move at all (separate from
  // whether the checks are clean) — lets us explain the right reason.
  roleCanSignoff: boolean;
  // Plain-language list of what must be cleared before a clean seal, e.g.
  // ["2 violations", "1 unverifiable check"]. Empty when ready.
  signoffBlockers: string[];
}) {
  // Spell out exactly why sign-off is unavailable, so the path to "done" is
  // never a guess (Maya/Hank): role first, then open issues, then ready.
  const signoffReason = !roleCanSignoff
    ? `Your role can't seal this case from its current state.`
    : signoffBlockers.length > 0
      ? `Resolve ${signoffBlockers.join(" and ")} first — record a finding or clear each item, then sign-off unlocks.`
      : "";

  // Look up the evidence label(s) behind each check, so a reviewer can see
  // which document drove a Violation/Exception without cross-referencing the
  // Evidence panel by eye (Hank).
  const evidenceById = new Map(evidence.map((e) => [e.id, e]));
  const linkedEvidence = (check: ReplayCheck): EvidenceItem[] =>
    check.evidenceIds
      .map((id) => evidenceById.get(id))
      .filter((e): e is EvidenceItem => Boolean(e));

  // At-a-glance rollup of the whole check set, worst-news-first, so the one job
  // of this screen is legible the instant it loads (Hank).
  const statusCounts = checks.reduce<Record<CheckStatus, number>>(
    (acc, c) => {
      acc[c.status] += 1;
      return acc;
    },
    { Violation: 0, Exception: 0, Unverifiable: 0, Pass: 0 },
  );

  // Map a check to the finding that wrote it up (matched by rule), so the
  // inline rationale's "see finding" pointer can jump straight there (Leo).
  const findingByRule = new Map(findings.map((f) => [f.rule, f]));
  return (
    <section className="rounded-[22px] border border-line bg-white p-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="font-display text-[22px] font-bold text-ink">
            <Term>Replay</Term>{" "}Checks &amp;{" "}
            <Term define={glossFor("finding")}>Findings</Term>
          </h2>
          {/* Plain-language gloss right under the jargon heading, so the title
              itself never has to be the thing a first-timer can't read (Leo). */}
          <p className="mt-1 text-[13px] text-muted">
            Re-checking the loan against the policy that was in force when it was approved.
          </p>
          {/* One-line tally of where the checks landed, worst first — the
              answer to "what is the state of this case?" without scrolling. */}
          <div className="mt-2 flex flex-wrap items-center gap-1.5 text-[12px]">
            {ROLLUP_ORDER.filter((s) => statusCounts[s] > 0).map((s) => (
              <span
                key={s}
                className={`rounded-full px-2 py-0.5 font-semibold ${statusClasses[s]}`}
              >
                {statusCounts[s]}{" "}
                {statusCounts[s] === 1 ? STATUS_LABELS[s].one : STATUS_LABELS[s].many}
              </span>
            ))}
          </div>
        </div>
        <button
          onClick={onRequestEvidence}
          className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold leading-none text-white hover:opacity-90"
        >
          Request evidence
        </button>
      </div>

      {/* Plain-language key so a first-time reviewer knows what each status word means. */}
      <div className="mt-5">
        <CheckLegend />
      </div>

      <div className="mt-5 space-y-3.5">
        {checks.map((check) => (
          <article
            key={check.id}
            className="flex min-h-[68px] items-center justify-between gap-4 rounded-[14px] border border-line bg-surface px-4 py-3"
          >
            <div className="min-w-0">
              <h3 className="text-[15px] font-semibold text-ink">
                <GlossedText>{check.rule}</GlossedText>
              </h3>
              <p className="mt-1 text-xs text-muted">
                <GlossedText>{check.detail}</GlossedText>
                {check.rationaleRequired && !check.rationale
                  ? " · rationale required"
                  : ""}
              </p>
              {/* Inline rationale excerpt so a reviewer sees the "why" without
                  opening the finding first (Hank). Full text lives on the finding. */}
              {check.rationale ? (
                <p className="mt-1.5 border-l-2 border-line pl-2 text-xs italic text-ink/70">
                  “<GlossedText>{check.rationale}</GlossedText>”
                  {findingByRule.has(check.rule) ? (
                    <Link
                      href={`/findings/${findingByRule.get(check.rule)!.id}`}
                      className="ml-1 not-italic font-medium text-brand-blue hover:underline"
                    >
                      — see full finding →
                    </Link>
                  ) : (
                    <span className="ml-1 not-italic text-muted">— see finding for full text</span>
                  )}
                </p>
              ) : null}
              {/* Name the document(s) this check leans on AND mirror each one's
                  status, so a flagged check visibly shows its evidence is broken —
                  no eyeball-matching names across the two panels (Hank). */}
              {linkedEvidence(check).length > 0 ? (
                <div className="mt-1.5 flex flex-wrap items-center gap-x-1.5 gap-y-1 text-[11px] text-muted">
                  <span className="font-semibold uppercase tracking-wide">Based on</span>
                  {linkedEvidence(check).map((e, i) => (
                    <span key={e.id} className="inline-flex items-center gap-1">
                      {i > 0 ? <span className="text-muted/60">·</span> : null}
                      <span className="text-ink">{e.label}</span>
                      <span
                        className={`rounded-full px-1.5 py-0.5 text-[10px] font-semibold ${EVIDENCE_STATUS_CLASSES[e.status]}`}
                      >
                        <Term define={glossFor(e.status)}>{e.status}</Term>
                      </span>
                    </span>
                  ))}
                </div>
              ) : null}
            </div>
            <span
              className={`min-w-[126px] shrink-0 rounded-full px-3 py-2 text-center text-[13px] font-semibold ${statusClasses[check.status]}`}
            >
              {check.status}
            </span>
          </article>
        ))}
      </div>

      {/* Readiness checklist: when sign-off is blocked, say exactly what's in
          the way and how to clear it — never a dead, unexplained button. */}
      {!canSignoff && signoffReason ? (
        <div
          id="signoff-reason"
          className="mt-6 rounded-[12px] border border-chip-amber-fg/30 bg-chip-amber-bg px-4 py-3 text-[13px] text-chip-amber-fg"
          role="status"
        >
          <span className="font-semibold">Not ready to seal.</span> {signoffReason}
        </div>
      ) : null}

      <div className="mt-4 flex flex-wrap gap-4">
        <button
          onClick={onCreateFinding}
          className="rounded-full bg-ink px-5 py-3 text-sm font-semibold text-white hover:opacity-90"
        >
          Create finding
        </button>
        <button
          onClick={onReadyForSignoff}
          disabled={!canSignoff}
          aria-describedby={!canSignoff ? "signoff-reason" : undefined}
          className="rounded-full bg-brand-green px-5 py-3 text-sm font-semibold text-white hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
          title={signoffReason}
        >
          Ready for sign-off
        </button>
      </div>
    </section>
  );
}
