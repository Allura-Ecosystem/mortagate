'use client';

import { use } from 'react';
import { AccentBar } from '@/components/veridact/accent-bar';
import { StatusChip } from '@/components/veridact/status-chip';
import { evaluate } from '@/engine/evaluator';
import { getPersona, personaToFacts } from '@/engine/personas';
import { formatCurrency, formatPercent, formatDate } from '@/lib/utils';
import { notFound } from 'next/navigation';

export default function Receipt({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const persona = getPersona(id);
  if (!persona) notFound();

  const facts = personaToFacts(persona);
  const result = evaluate({ applicationId: persona.id, facts });

  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 px-6 py-12 max-w-2xl mx-auto w-full">
        <div className="text-center mb-8">
          <p className="text-xs text-veridact-fg-muted tracking-wide uppercase mb-2">Decision Receipt</p>
          <h1 className="font-[family-name:var(--font-outfit)] text-2xl font-bold">Veridact</h1>
          <p className="text-veridact-fg-muted text-sm">Every decision has a receipt.</p>
        </div>

        <div className="border border-veridact-border rounded-lg divide-y divide-veridact-border">
          {/* Header */}
          <div className="p-5 flex justify-between items-start">
            <div>
              <p className="font-semibold">{persona.name}</p>
              <p className="text-sm text-veridact-fg-muted">Application: {persona.id.toUpperCase()}-001</p>
            </div>
            <StatusChip verdict={result.verdict} />
          </div>

          {/* Facts */}
          <div className="p-5">
            <p className="text-xs text-veridact-fg-muted uppercase tracking-wide mb-3">Evaluated Facts</p>
            <div className="grid grid-cols-2 gap-y-2 gap-x-8 text-sm">
              <div className="flex justify-between"><span className="text-veridact-fg-muted">FICO Score</span><span>{persona.fico}</span></div>
              <div className="flex justify-between"><span className="text-veridact-fg-muted">DTI Ratio</span><span>{formatPercent(persona.dti)}</span></div>
              <div className="flex justify-between"><span className="text-veridact-fg-muted">Annual Income</span><span>{formatCurrency(persona.annualIncome)}</span></div>
              <div className="flex justify-between"><span className="text-veridact-fg-muted">Property Value</span><span>{formatCurrency(persona.propertyValue)}</span></div>
              <div className="flex justify-between"><span className="text-veridact-fg-muted">LTV Ratio</span><span>{formatPercent(persona.ltv)}</span></div>
              <div className="flex justify-between"><span className="text-veridact-fg-muted">Employment</span><span>{Math.round(persona.employmentTenureMonths / 12 * 10) / 10} yr</span></div>
            </div>
          </div>

          {/* Rule-by-rule */}
          <div className="p-5">
            <p className="text-xs text-veridact-fg-muted uppercase tracking-wide mb-3">
              Rule Results ({result.totalRulesEvaluated} rules evaluated)
            </p>
            <div className="space-y-3">
              {result.outcomes.map(o => (
                <div key={o.ruleCode} className="flex items-start gap-2 text-sm">
                  <span className={`mt-1 text-xs font-mono ${o.passed ? 'text-veridact-approved' : o.indeterminate ? 'text-veridact-fg-muted' : 'text-veridact-declined'}`}>
                    {o.passed ? 'PASS' : o.indeterminate ? 'N/A' : 'FAIL'}
                  </span>
                  <div>
                    <p><span className="font-medium">{o.ruleCode}</span> — {o.ruleLabel}</p>
                    <p className="text-veridact-fg-muted text-xs">
                      {o.factField} = {o.factValue !== null ? String(o.factValue) : 'null'} | {o.operator} {o.threshold}
                    </p>
                    {!o.passed && !o.indeterminate && <p className="text-veridact-declined text-xs mt-0.5">{o.explanation}</p>}
                    {o.regulatoryCitation && <p className="text-xs text-veridact-fg-muted">Ref: {o.regulatoryCitation}</p>}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Summary */}
          <div className="p-5 text-sm">
            <div className="grid grid-cols-2 gap-2">
              <div><span className="text-veridact-fg-muted">Hard Declines</span><p className="font-medium">{result.hardDeclineCount}</p></div>
              <div><span className="text-veridact-fg-muted">Soft Declines</span><p className="font-medium">{result.softDeclineCount}</p></div>
              <div><span className="text-veridact-fg-muted">Warnings</span><p className="font-medium">{result.warningCount}</p></div>
              <div><span className="text-veridact-fg-muted">Advisories</span><p className="font-medium">{result.advisoryCount}</p></div>
            </div>
          </div>

          {/* Footer */}
          <div className="p-5 text-xs text-veridact-fg-muted">
            <p>Evaluated: {formatDate(result.evaluationTimestamp)}</p>
            <p>Engine: Veridact PolicyRuleEvaluator v1 (TypeScript port)</p>
            <p>This receipt is append-only. It cannot be modified or deleted.</p>
          </div>
        </div>

        <div className="text-center mt-6">
          <a href={`/scenarios/${persona.id}`} className="text-sm text-veridact-fg-muted underline underline-offset-4">&larr; Back to scenario</a>
        </div>
      </div>
      <AccentBar />
    </main>
  );
}
