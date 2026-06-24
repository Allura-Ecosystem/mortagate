import { cn } from '@/lib/utils';

export function CtaButton({
  children, onClick, disabled, className, href
}: {
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  className?: string;
  href?: string;
}) {
  const base = cn(
    'inline-block rounded-lg bg-veridact-accent px-8 py-4 text-base font-semibold text-veridact-bg',
    'transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-veridact-fg',
    disabled && 'opacity-35 cursor-not-allowed',
    className
  );

  if (href) {
    return <a href={href} className={base}>{children}</a>;
  }
  return <button onClick={onClick} disabled={disabled} className={base}>{children}</button>;
}
