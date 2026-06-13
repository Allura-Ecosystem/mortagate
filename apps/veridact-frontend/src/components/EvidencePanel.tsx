import type { EvidenceItem, EvidenceStatus } from "@/lib/types";
import { Term } from "./Term";
import { glossFor } from "@/lib/glossary";

// Missing/contradictory/expired evidence is a real outcome, not an error.
// Chip tokens (not inline hex) keep contrast consistent with every other badge.
// Exported as the single source for evidence-status colors so the check cards
// can mirror an item's status without re-typing the mapping (no drift).
export const EVIDENCE_STATUS_CLASSES: Record<EvidenceStatus, string> = {
  Linked: "bg-chip-green-bg text-chip-green-fg",
  Missing: "bg-chip-red-bg text-chip-red-fg",
  Contradictory: "bg-chip-red-bg text-chip-red-fg",
  Expired: "bg-chip-amber-bg text-chip-amber-fg",
  Mismatch: "bg-chip-amber-bg text-chip-amber-fg",
};

export function EvidencePanel({ evidence }: { evidence: EvidenceItem[] }) {
  return (
    <section className="rounded-[22px] border border-line bg-white p-6">
      <div className="flex items-center justify-between">
        <h2 className="font-display text-[22px] font-bold text-ink">Evidence</h2>
        <span className="text-[12px] text-muted">{evidence.length} items</span>
      </div>

      <div className="mt-5 space-y-3">
        {evidence.map((e) => (
          <article
            key={e.id}
            className="rounded-[14px] border border-line bg-surface p-4"
          >
            <div className="flex items-start justify-between gap-3">
              <div>
                <h3 className="text-[15px] font-semibold text-ink">{e.label}</h3>
                <p className="mt-0.5 text-[12px] text-muted">{e.kind}</p>
              </div>
              <span
                className={`rounded-full px-3 py-1 text-[12px] font-semibold ${EVIDENCE_STATUS_CLASSES[e.status]}`}
              >
                {/* Every hard word on the screen behaves the same: evidence
                    status words are tap-to-define, just like the rule jargon (Leo). */}
                <Term define={glossFor(e.status)}>{e.status}</Term>
              </span>
            </div>
            {e.note ? (
              <p className="mt-2 text-[12px] leading-snug text-chip-red-fg">{e.note}</p>
            ) : null}
          </article>
        ))}
      </div>
    </section>
  );
}
