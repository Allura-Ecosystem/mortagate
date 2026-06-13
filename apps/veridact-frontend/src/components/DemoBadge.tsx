// One honest, app-wide signal that this is illustrative mock data, not a live
// system of record. Munari's "no silent over-claim" rule: a sealed receipt and
// its hash must never be mistaken for a real legal artifact.

export function DemoBadge({ className = "" }: { className?: string }) {
  return (
    <span
      title="This build runs on illustrative sample data — it is not connected to a live system and creates no real records."
      className={`inline-flex items-center gap-1.5 rounded-full border border-chip-amber-fg/30 bg-chip-amber-bg px-2.5 py-0.5 text-[11px] font-semibold text-chip-amber-fg ${className}`}
    >
      <span aria-hidden="true" className="h-1.5 w-1.5 rounded-full bg-chip-amber-fg" />
      Demo data
    </span>
  );
}
