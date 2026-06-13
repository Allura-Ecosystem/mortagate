import type { Finding } from "@/lib/types";

// Single source of truth for the Exception/Violation chip,
// previously duplicated in three files.
export function SeverityBadge({ severity }: { severity: Finding["severity"] }) {
  const cls =
    severity === "Violation"
      ? "bg-chip-red-bg text-chip-red-fg"
      : "bg-chip-amber-bg text-chip-amber-fg";
  return (
    <span className={`rounded-full px-3 py-1 text-[12px] font-semibold ${cls}`}>
      {severity}
    </span>
  );
}
