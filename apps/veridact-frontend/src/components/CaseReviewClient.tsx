"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { AuditCase, ReplayCheck, EvidenceItem, Finding, CaseState } from "@/lib/types";
import { RiskBadge } from "./RiskBadge";
import { StateBadge, SlaBadge } from "./StateBadge";
import { EvidencePanel } from "./EvidencePanel";
import { ReplayChecksFindings } from "./replay/ReplayChecksFindings";
import { SeverityBadge } from "./SeverityBadge";
import * as commands from "@/lib/commands";
import { can } from "@/lib/roles";
import { CURRENT_ROLE } from "@/lib/roles";

// Plain-language "you are here / do this next" cue for each case state, so a
// first-time reviewer never has to guess what the screen expects of them.
const NEXT_STEP: Record<CaseState, string> = {
  "In Review": "Work the replay checks. Request evidence if something can't be confirmed, or mark the case ready for sign-off when every check is settled.",
  "Evidence Needed": "Waiting on requested documents. The case moves on once the evidence is linked.",
  "Ready for Sign-off": "A reviewer can now seal the receipt. Once sealed it cannot be edited.",
  Closed: "This case is sealed. Open its receipt to see the locked record.",
};

export function CaseReviewClient({
  auditCase,
  checks,
  evidence,
  findings,
  policyLabel,
}: {
  auditCase: AuditCase;
  checks: ReplayCheck[];
  evidence: EvidenceItem[];
  findings: Finding[];
  policyLabel: string;
}) {
  const router = useRouter();
  const [state, setState] = useState<CaseState>(auditCase.state);
  const [banner, setBanner] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Every action goes through the guarded command layer. The component does
  // not decide whether a move is legal — it asks, then renders the result.
  function run(result: commands.CommandResult) {
    if (result.ok) {
      // Some successful commands don't move the case (e.g. recording a finding).
      if (result.nextState) setState(result.nextState);
      setBanner(result.message);
      setError(null);
    } else {
      setBanner(null);
      setError(result.reason);
    }
  }

  function requestEvidence() {
    run(commands.requestEvidence(state, CURRENT_ROLE));
  }
  function readyForSignoff() {
    run(commands.markReadyForSignoff(state, CURRENT_ROLE));
  }

  // The current role's permission to record a finding gates the button.
  const mayCreateFinding = can(CURRENT_ROLE, "create_finding");

  // Two independent gates on "Ready for sign-off", surfaced separately so the
  // reviewer is never left guessing why the button is off:
  //  1. role/state — may this role make this move from this state at all?
  //  2. readiness — are there open violations / unverifiable checks to clear?
  const roleCanSignoff = commands.canIssueCommand(state, "Ready for Sign-off", CURRENT_ROLE);
  const blockers = commands.signoffBlockers(checks);

  return (
    <main className="p-8">
      <div className="flex items-center justify-between gap-4">
        <button
          onClick={() => router.push("/audit-queue")}
          className="text-[13px] font-medium text-muted hover:text-ink"
        >
          ← Back to queue
        </button>
        <Link
          href={`/receipts/${auditCase.id}`}
          className="text-[13px] font-medium text-brand-blue hover:underline"
        >
          View sign-off receipt →
        </Link>
      </div>

      {/* Case header */}
      <div className="mt-3 rounded-[18px] border border-line bg-white p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex items-center gap-3">
              <h1 className="font-display text-[28px] font-bold text-ink">{auditCase.loanNumber}</h1>
              <RiskBadge risk={auditCase.risk} />
              <StateBadge state={state} />
            </div>
            <p className="mt-1 text-sm text-muted">
              {auditCase.borrower} · {auditCase.product} · {auditCase.branch}
            </p>
          </div>
          <SlaBadge status={auditCase.slaStatus} dueInDays={auditCase.dueInDays} />
        </div>

        <dl className="mt-5 grid grid-cols-2 gap-x-6 gap-y-3 text-sm md:grid-cols-4">
          <Meta label="Original approver" value={auditCase.originalApprover} />
          <Meta label="Approval date" value={auditCase.approvalDate} />
          <Meta label="Policy in force" value={policyLabel} />
          <Meta label="Assigned auditor" value={auditCase.assignedAuditor} />
        </dl>
      </div>

      {banner ? (
        <div className="mt-4 rounded-[12px] border border-brand-green/40 bg-chip-green-bg px-4 py-3 text-[13px] font-medium text-chip-green-fg">
          {banner}
        </div>
      ) : null}

      {/* Blocked actions explain themselves — no silent failure. */}
      {error ? (
        <div
          role="alert"
          className="mt-4 rounded-[12px] border border-brand-red/40 bg-chip-red-bg px-4 py-3 text-[13px] font-medium text-chip-red-fg"
        >
          {error}
        </div>
      ) : null}

      {/* You-are-here cue: current state + the next action expected. */}
      <div className="mt-4 flex flex-wrap items-center gap-x-2 gap-y-1 rounded-[12px] border border-line bg-surface px-4 py-3 text-[13px] text-ink">
        <span className="font-semibold uppercase tracking-wide text-muted">Next step</span>
        <StateBadge state={state} />
        <span className="text-muted">{NEXT_STEP[state]}</span>
      </div>

      {/* Two-pane review */}
      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        <EvidencePanel evidence={evidence} />
        <ReplayChecksFindings
          checks={checks}
          evidence={evidence}
          findings={findings}
          onRequestEvidence={requestEvidence}
          onCreateFinding={() =>
            mayCreateFinding
              ? router.push(`/findings/new?caseId=${auditCase.id}`)
              : setError(`Your role (${CURRENT_ROLE}) cannot record findings.`)
          }
          onReadyForSignoff={readyForSignoff}
          canSignoff={roleCanSignoff && blockers.length === 0}
          roleCanSignoff={roleCanSignoff}
          signoffBlockers={blockers}
        />
      </div>

      {/* Existing findings on this case */}
      {findings.length > 0 ? (
        <section className="mt-6 rounded-[18px] border border-line bg-white p-6">
          <h2 className="font-display text-[20px] font-bold text-ink">Findings on this case</h2>
          <div className="mt-4 space-y-3">
            {findings.map((f) => (
              <Link
                key={f.id}
                href={`/findings/${f.id}`}
                className="block rounded-[12px] border border-line bg-surface p-4 hover:bg-peach/40"
              >
                <div className="flex items-center justify-between">
                  <span className="text-[15px] font-semibold text-ink">{f.rule}</span>
                  <SeverityBadge severity={f.severity} />
                </div>
                <p className="mt-1 text-[13px] text-muted">{f.summary}</p>
              </Link>
            ))}
          </div>
        </section>
      ) : null}
    </main>
  );
}

function Meta({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-[12px] uppercase tracking-wide text-muted">{label}</dt>
      <dd className="mt-0.5 font-medium text-ink">{value}</dd>
    </div>
  );
}
