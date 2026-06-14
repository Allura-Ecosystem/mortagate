'use client';

import { use } from 'react';
import { AccentBar } from '@/components/veridact/accent-bar';
import { evaluate } from '@/engine/evaluator';
import { getPersona, personaToFacts } from '@/engine/personas';
import { formatDate } from '@/lib/utils';
import { notFound } from 'next/navigation';

export default function AdverseActionNotice({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const persona = getPersona(id);
  if (!persona) notFound();

  const facts = personaToFacts(persona);
  const result = evaluate({ applicationId: persona.id, facts });

  if (result.verdict !== 'HARD_DECLINED') {
    return (
      <main className="flex flex-col min-h-dvh items-center justify-center px-6">
        <p className="text-veridact-fg-muted">No adverse action notice required — application was not declined.</p>
        <a href={`/scenarios/${persona.id}`} className="text-sm text-veridact-fg-muted underline underline-offset-4 mt-4">&larr; Back</a>
      </main>
    );
  }

  const declineReasons = result.outcomes
    .filter(o => !o.passed && !o.indeterminate && o.severity === 'HARD_DECLINE')
    .slice(0, 4)
    .map(o => o.explanation);

  const respondByDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toLocaleDateString('en-US', {
    year: 'numeric', month: 'long', day: 'numeric',
  });

  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 px-6 py-12 max-w-2xl mx-auto w-full">
        <div className="border border-veridact-border rounded-lg bg-veridact-card">
          {/* Header */}
          <div className="p-6 border-b border-veridact-border">
            <p className="text-xs text-veridact-fg-muted uppercase tracking-wide mb-1">Notice of Action Taken</p>
            <h1 className="font-[family-name:var(--font-outfit)] text-xl font-bold">
              Adverse Action Notice
            </h1>
            <p className="text-sm text-veridact-fg-muted mt-1">
              Equal Credit Opportunity Act (ECOA) — 12 CFR 1002.9
            </p>
          </div>

          {/* Action taken */}
          <div className="p-6 border-b border-veridact-border">
            <p className="text-sm font-semibold mb-2">Statement of Action Taken</p>
            <p className="text-sm">
              Your application for credit was not approved. This notice is provided in accordance with
              the Equal Credit Opportunity Act and Regulation B (12 CFR Part 1002).
            </p>
          </div>

          {/* Specific reasons */}
          <div className="p-6 border-b border-veridact-border">
            <p className="text-sm font-semibold mb-2">Principal Reason(s) for Adverse Action</p>
            <ol className="list-decimal list-inside space-y-2 text-sm">
              {declineReasons.map((reason, i) => (
                <li key={i}>{reason}</li>
              ))}
            </ol>
          </div>

          {/* Creditor information */}
          <div className="p-6 border-b border-veridact-border">
            <p className="text-sm font-semibold mb-2">Creditor Information</p>
            <div className="text-sm space-y-1">
              <p>Veridact Mortgage Services</p>
              <p className="text-veridact-fg-muted">A product of Allura Financial Technology</p>
            </div>
          </div>

          {/* ECOA notice */}
          <div className="p-6 border-b border-veridact-border bg-veridact-bg/50">
            <p className="text-sm font-semibold mb-2">Your Rights Under ECOA</p>
            <p className="text-sm text-veridact-fg-muted leading-relaxed">
              The Federal Equal Credit Opportunity Act prohibits creditors from discriminating against credit
              applicants on the basis of race, color, religion, national origin, sex, marital status, or age
              (provided the applicant has the capacity to enter into a binding contract); because all or part
              of the applicant&rsquo;s income derives from any public assistance program; or because the applicant has
              in good faith exercised any right under the Consumer Credit Protection Act.
            </p>
            <p className="text-sm text-veridact-fg-muted mt-3">
              The federal agency that administers compliance with this law is the Consumer Financial
              Protection Bureau, 1700 G Street NW, Washington, DC 20552.
            </p>
          </div>

          {/* FCRA disclosure */}
          <div className="p-6 border-b border-veridact-border">
            <p className="text-sm font-semibold mb-2">Fair Credit Reporting Act Disclosure</p>
            <p className="text-sm text-veridact-fg-muted leading-relaxed">
              You have the right to obtain a free copy of your credit report from the consumer reporting
              agency that provided the report used in this decision, if you request it within 60 days of
              receiving this notice. You also have the right to dispute the accuracy or completeness of any
              information in your credit report.
            </p>
          </div>

          {/* Timing */}
          <div className="p-6 text-sm text-veridact-fg-muted">
            <p>Date of notice: {formatDate(new Date().toISOString())}</p>
            <p>Respond by: {respondByDate}</p>
            <p className="mt-2 text-xs italic">
              This notice was generated by the Veridact policy engine. Reasons are derived from the specific
              policy rules that triggered the adverse action — not from generic templates.
            </p>
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
