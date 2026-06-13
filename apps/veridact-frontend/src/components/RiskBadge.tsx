import type { Risk } from "@/lib/types";

// Risk is conveyed by colour AND a shape sigil AND the word — never colour alone.
const MAP: Record<Risk, { chip: string; sigil: string }> = {
  Critical: { chip: "bg-chip-red-bg text-chip-red-fg", sigil: "▲" },
  High: { chip: "bg-chip-amber-bg text-chip-amber-fg", sigil: "■" },
  Medium: { chip: "bg-chip-blue-bg text-chip-blue-fg", sigil: "●" },
  Low: { chip: "bg-chip-green-bg text-chip-green-fg", sigil: "▾" },
};

export function RiskBadge({ risk }: { risk: Risk }) {
  const s = MAP[risk];
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[12px] font-semibold ${s.chip}`}
    >
      <span aria-hidden="true">{s.sigil}</span>
      {risk}
    </span>
  );
}
