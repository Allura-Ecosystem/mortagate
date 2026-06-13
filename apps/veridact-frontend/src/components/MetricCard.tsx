// Accent is a palette token name, not a raw hex — the bottom rule reads the
// same brand color the rest of the app uses, so cards can't drift off-palette.
type AccentToken =
  | "primary"
  | "brand-red"
  | "brand-amber"
  | "brand-green"
  | "brand-blue"
  | "muted";

export function MetricCard({
  value,
  label,
  accent,
}: {
  value: number | string;
  label: string;
  accent: AccentToken;
}) {
  return (
    <div
      className="rounded-[16px] border border-line bg-white p-4"
      style={{ borderBottom: `3px solid var(--color-${accent})` }}
    >
      <div className="font-display text-[34px] font-bold leading-none text-ink">
        {value}
      </div>
      <div className="mt-2 text-[13px] text-muted">{label}</div>
    </div>
  );
}
