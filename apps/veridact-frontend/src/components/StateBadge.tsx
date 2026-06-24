import type { CaseState, SlaStatus } from "@/lib/types";

const STATE_MAP: Record<CaseState, string> = {
  "In Review": "bg-chip-blue-bg text-chip-blue-fg",
  "Evidence Needed": "bg-chip-amber-bg text-chip-amber-fg",
  "Ready for Sign-off": "bg-chip-green-bg text-chip-green-fg",
  Closed: "bg-chip-neutral-bg text-chip-neutral-fg",
};

export function StateBadge({ state }: { state: CaseState }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-1 text-[12px] font-semibold ${STATE_MAP[state]}`}
    >
      {state}
    </span>
  );
}

const SLA_MAP: Record<SlaStatus, string> = {
  "On Track": "bg-chip-green-bg text-chip-green-fg",
  "At Risk": "bg-chip-amber-bg text-chip-amber-fg",
  Overdue: "bg-chip-red-bg text-chip-red-fg",
};

export function SlaBadge({ status, dueInDays }: { status: SlaStatus; dueInDays: number }) {
  const label =
    dueInDays < 0
      ? `Overdue ${Math.abs(dueInDays)}d`
      : dueInDays === 0
        ? "Due today"
        : `${dueInDays}d left`;
  return (
    <span className="inline-flex flex-col">
      <span
        className={`inline-flex w-fit items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ${SLA_MAP[status]}`}
      >
        {status}
      </span>
      <span className="mt-0.5 text-[11px] text-muted">{label}</span>
    </span>
  );
}
