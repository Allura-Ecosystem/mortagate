'use client';

import { AccentBar } from '@/components/veridact/accent-bar';
import { StatusChip } from '@/components/veridact/status-chip';
import { CtaButton } from '@/components/veridact/cta-button';
import { evaluate } from '@/engine/evaluator';
import { getPersona, personaToFacts } from '@/engine/personas';
import { formatPercent, formatCurrency } from '@/lib/utils';

export default function AuditGap() {
  const sabir = getPersona('sabir')!;
  const facts = personaToFacts(sabir);
  const result = evaluate({ applicationId: 'sabir', facts });

  const failedRules = result.outcomes.filter(o => !o.passed && !o.indeterminate);

  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 px-6 py-12 max-w-2xl mx-auto w-full">
        <h1 className="font-[family-name:var(--font-outfit)] text-3xl md:text-4xl font-bold leading-tight text-center mb-2">
          The Audit Gap
        </h1>
        <p className="text-center text-veridact-fg-muted mb-10 max-w-md mx-auto">
          Your guideline says yes. The regulation says no. We catch the gap.
        </p>

        {/* Borrower profile */}
        <div className="bg-veridact-card rounded-lg p-6 mb-6 border border-veridact-border">
          <h2 className="font-semibold text-lg mb-4">{sabir.name}</h2>
          <div className="grid grid-cols-2 gap-y-3 gap-x-8 text-sm">
            <div><span className="text-veridact-fg-muted">FICO</span><p className="font-medium">{sabir.fico}</p></div>
            <div><span className="text-veridact-fg-muted">DTI</span><p className="font-medium">{formatPercent(sabir.dti)}</p></div>
            <div><span className="text-veridact-fg-muted">Income</span><p className="font-medium">{formatCurrency(sabir.annualIncome)}</p></div>
            <div><span className="text-veridact-fg-muted">Employment</span><p className="font-medium">{Math.round(sabir.employmentTenureMonths / 12)} years</p></div>
          </div>
        </div>

        {/* The gap */}
        <div className="grid md:grid-cols-2 gap-4 mb-8">
          <div className="bg-veridact-card rounded-lg p-6 border border-veridact-border text-center">
            <p className="text-xs text-veridact-fg-muted tracking-wide uppercase mb-3">Internal Guideline (45%)</p>
            <div className="inline-block bg-veridact-approved rounded-full px-3.5 py-1.5 text-sm font-semibold text-white mb-2">
              Would Approve
            </div>
            <p className="text-veridact-fg-muted text-sm mt-2">
              DTI {formatPercent(sabir.dti)} &lt; 45% guideline
            </p>
          </div>
          <div className="bg-veridact-card rounded-lg p-6 border border-veridact-border text-center">
            <p className="text-xs text-veridact-fg-muted tracking-wide uppercase mb-3">CFPB Regulation (43%)</p>
            <StatusChip verdict="HARD_DECLINED" />
            <p className="text-veridact-fg-muted text-sm mt-2">
              DTI {formatPercent(sabir.dti)} &gt; 43% QM threshold
            </p>
          </div>
        </div>

        {/* Why this matters */}
        <div className="bg-veridact-accent/5 rounded-lg p-6 mb-8 border border-veridact-accent/20">
          <h3 className="font-[family-name:var(--font-outfit)] font-semibold text-lg mb-2">Why this matters</h3>
          <p className="text-sm text-veridact-fg leading-relaxed">
            The 2% gap between a 43% regulatory threshold and a 45% internal guideline is where fines happen.
            When an internal guideline is more permissive than the regulation it implements, every approval in that gap
            is a compliance risk. Veridact makes the gap <strong>visible, queryable, and auditable</strong>.
          </p>
        </div>

        {/* Rule-by-rule receipt */}
        <h3 className="font-semibold mb-3">Rules Evaluated ({result.totalRulesEvaluated})</h3>
        <div className="space-y-2 mb-8">
          {result.outcomes.map(o => (
            <div key={o.ruleCode} className={`flex items-start gap-3 p-3 rounded-lg text-sm ${!o.passed && !o.indeterminate ? 'bg-veridact-declined/5' : 'bg-veridact-approved/5'}`}>
              <span className={`mt-0.5 w-2 h-2 rounded-full shrink-0 ${!o.passed && !o.indeterminate ? 'bg-veridact-declined' : 'bg-veridact-approved'}`} />
              <div>
                <p className="font-medium">{o.ruleLabel}</p>
                <p className="text-veridact-fg-muted">
                  {o.factField}: {o.factValue !== null ? (typeof o.factValue === 'number' && o.factValue < 1 && o.factValue > 0 ? formatPercent(o.factValue as number) : String(o.factValue)) : 'N/A'}
                  {' '}{o.operator} {o.threshold !== null ? (o.threshold < 1 && o.threshold > 0 ? formatPercent(o.threshold) : String(o.threshold)) : ''}
                </p>
                {o.regulatoryCitation && (
                  <p className="text-xs text-veridact-fg-muted mt-1">📋 {o.regulatoryCitation}</p>
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="flex flex-col items-center gap-3">
          <CtaButton href="/architecture">See the architecture</CtaButton>
          <div className="flex gap-4 text-sm">
            <a href="/receipt/sabir" className="text-veridact-fg-muted underline underline-offset-4">Decision receipt</a>
            <a href="/notice/sabir" className="text-veridact-fg-muted underline underline-offset-4">Adverse action notice</a>
          </div>
        </div>
      </div>
      <AccentBar />
    </main>
  );
}
