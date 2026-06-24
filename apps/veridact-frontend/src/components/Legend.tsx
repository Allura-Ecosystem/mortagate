// A small, always-visible key so a first-time user can decode the
// status words and risk shapes without already knowing the field.

import { Term } from "./Term";
import { glossFor } from "@/lib/glossary";

const CHECK_ITEMS: { label: string; chip: string; meaning: string }[] = [
  { label: "Pass", chip: "bg-chip-green-bg text-chip-green-fg", meaning: "rule met" },
  { label: "Exception", chip: "bg-chip-amber-bg text-chip-amber-fg", meaning: "bent — e.g. DTI 47% over a 45% cap — but a manager OK'd it at the time" },
  { label: "Unverifiable", chip: "bg-chip-amber-bg text-chip-amber-fg", meaning: "can't confirm — evidence missing or expired" },
  { label: "Violation", chip: "bg-chip-red-bg text-chip-red-fg", meaning: "broken, with no valid approval" },
];

const RISK_ITEMS: { sigil: string; label: string }[] = [
  { sigil: "▲", label: "Critical" },
  { sigil: "■", label: "High" },
  { sigil: "●", label: "Medium" },
  { sigil: "▾", label: "Low" },
];

export function CheckLegend() {
  return (
    <div className="rounded-[12px] border border-line bg-surface p-3">
      <p className="text-[11px] font-semibold uppercase tracking-wide text-muted">
        What the status words mean
      </p>
      <div className="mt-2 flex flex-wrap gap-x-4 gap-y-2">
        {CHECK_ITEMS.map((i) => (
          <span key={i.label} className="inline-flex items-center gap-1.5 text-[12px] text-ink">
            <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${i.chip}`}>
              {/* Every status word on the screen behaves the same — the legend
                  chips are tap-to-define too, matching the evidence chips (Leo). */}
              <Term define={glossFor(i.label)}>{i.label}</Term>
            </span>
            <span className="text-muted">{i.meaning}</span>
          </span>
        ))}
      </div>
    </div>
  );
}

export function RiskLegend() {
  return (
    <span className="inline-flex flex-wrap items-center gap-x-3 gap-y-1 text-[12px] text-muted">
      <span className="font-semibold uppercase tracking-wide">Risk:</span>
      {RISK_ITEMS.map((i) => (
        <span key={i.label} className="inline-flex items-center gap-1">
          <span aria-hidden="true">{i.sigil}</span>
          {i.label}
        </span>
      ))}
    </span>
  );
}
