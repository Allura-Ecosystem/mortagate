'use client';

import { use } from 'react';
import { AccentBar } from '@/components/veridact/accent-bar';
import { StatusChip } from '@/components/veridact/status-chip';
import { evaluate } from '@/engine/evaluator';
import { getPersona, personaToFacts, PERSONAS } from '@/engine/personas';
import { formatCurrency, formatPercent } from '@/lib/utils';
import { notFound } from 'next/navigation';

export default function ScenarioDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const persona = getPersona(id);
  if (!persona) notFound();

  const facts = personaToFacts(persona);
  const result = evaluate({ applicationId: persona.id, facts });

  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 px-6 py-12 max-w-2xl mx-auto w-full">
        <a href="/scenarios" className="text-sm text-veridact-fg-muted mb-6 inline-block">&larr; All scenarios</a>

        <div className="flex items-start justify-between mb-6">
          <h1 className="font-[family-name:var(--font-outfit)] text-2xl font-bold">{persona.name}</h1>
          <StatusChip verdict={result.verdict} />
        </div>

        {/* Profile */}
        <div className="bg-veridact-card rounded-lg p-5 border border-veridact-border mb-6">
          <div className="grid grid-cols-2 gap-y-3 gap-x-8 text-sm">
            <div><span className="text-veridact-fg-muted">FICO</span><p className="font-medium">{persona.fico}</p></div>
            <div><span className="text-veridact-fg-muted">DTI</span><p className="font-medium">{formatPercent(persona.dti)}</p></div>
            <div><span className="text-veridact-fg-muted">Income</span><p className="font-medium">{formatCurrency(persona.annualIncome)}</p></div>
            <div><span className="text-veridact-fg-muted">Property</span><p className="font-medium">{formatCurrency(persona.propertyValue)}</p></div>
            <div><span className="text-veridact-fg-muted">Employment</span><p className="font-medium">{Math.round(persona.employmentTenureMonths / 12 * 10) / 10} years</p></div>
            <div><span className="text-veridact-fg-muted">LTV</span><p className="font-medium">{formatPercent(persona.ltv)}</p></div>
          </div>
        </div>

        <p className="text-sm text-veridact-fg-muted mb-6 italic">{persona.story}</p>

        {/* Rules */}
        <h2 className="font-semibold mb-3">Rules Evaluated ({result.totalRulesEvaluated})</h2>
        <div className="space-y-2 mb-8">
          {result.outcomes.map(o => (
            <div key={o.ruleCode} className={`flex items-start gap-3 p-3 rounded-lg text-sm ${!o.passed && !o.indeterminate ? 'bg-veridact-declined/5' : 'bg-veridact-approved/5'}`}>
              <span className={`mt-0.5 w-2 h-2 rounded-full shrink-0 ${!o.passed && !o.indeterminate ? 'bg-veridact-declined' : 'bg-veridact-approved'}`} />
              <div>
                <p className="font-medium">{o.ruleLabel} <span className="text-veridact-fg-muted font-normal">({o.passed ? 'PASS' : o.indeterminate ? 'INDETERMINATE' : 'FAIL'})</span></p>
                <p className="text-veridact-fg-muted">{o.explanation}</p>
                {o.regulatoryCitation && <p className="text-xs text-veridact-fg-muted mt-1">📋 {o.regulatoryCitation}</p>}
              </div>
            </div>
          ))}
        </div>

        <div className="flex gap-4 text-sm">
          <a href={`/receipt/${persona.id}`} className="text-veridact-fg-muted underline underline-offset-4">Decision receipt</a>
          {result.verdict === 'HARD_DECLINED' && (
            <a href={`/notice/${persona.id}`} className="text-veridact-fg-muted underline underline-offset-4">Adverse action notice</a>
          )}
        </div>
      </div>
      <AccentBar />
    </main>
  );
}
