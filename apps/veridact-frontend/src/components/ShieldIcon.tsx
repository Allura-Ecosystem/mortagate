// The Veridact shield mark, reused wherever a "sealed / verified" cue is
// needed. Replaces emoji (🔒) which renders inconsistently and reads poorly
// to screen readers. Decorative by default; pass a title to give it a name.
export function ShieldIcon({
  size = 18,
  className,
  title,
}: {
  size?: number;
  className?: string;
  title?: string;
}) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      className={className}
      role={title ? "img" : undefined}
      aria-hidden={title ? undefined : "true"}
      aria-label={title}
    >
      {title ? <title>{title}</title> : null}
      <path
        d="M12 2l8 3v6c0 5-3.4 8.5-8 11-4.6-2.5-8-6-8-11V5l8-3z"
        fill="currentColor"
      />
      <path
        d="M8.5 12l2.4 2.4L16 9.3"
        stroke="#ffffff"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
