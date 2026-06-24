import type { Verdict } from '@/engine/types';
import { cn } from '@/lib/utils';

const CHIP_CONFIG: Record<Verdict, { bg: string; text: string; label: string }> = {
  APPROVED: { bg: 'bg-veridact-approved', text: 'text-veridact-approved-on', label: 'Approved' },
  APPROVED_WITH_CONDITIONS: { bg: 'bg-veridact-conditions', text: 'text-veridact-conditions-on', label: 'Approved with conditions' },
  PENDING_REVIEW: { bg: 'bg-veridact-review', text: 'text-veridact-review-on', label: 'In review' },
  HARD_DECLINED: { bg: 'bg-veridact-declined', text: 'text-veridact-declined-on', label: 'Not approved' },
};

export function StatusChip({ verdict, className }: { verdict: Verdict; className?: string }) {
  const config = CHIP_CONFIG[verdict];
  return (
    <span className={cn(config.bg, config.text, 'inline-block rounded-full px-3.5 py-1.5 text-sm font-semibold', className)}>
      {config.label}
    </span>
  );
}
