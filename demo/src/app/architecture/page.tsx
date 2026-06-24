import { AccentBar } from '@/components/veridact/accent-bar';
import { CtaButton } from '@/components/veridact/cta-button';

const STATS = [
  { value: '3 SOQL + 1 DML', label: 'for 200 applications' },
  { value: '7', label: 'policy rules (data, not code)' },
  { value: '14', label: 'architectural decisions documented' },
  { value: '0', label: 'records ever updated or deleted' },
];

export default function Architecture() {
  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 px-6 py-12 max-w-2xl mx-auto w-full">
        <h1 className="font-[family-name:var(--font-outfit)] text-3xl md:text-4xl font-bold leading-tight text-center mb-2">
          How it works
        </h1>
        <p className="text-center text-veridact-fg-muted mb-10">
          Three layers. One contract. Zero magic.
        </p>

        {/* Engine diagram */}
        <div className="bg-veridact-card rounded-lg p-6 border border-veridact-border mb-8">
          <div className="space-y-0">
            {[
              { layer: 'Layer 1', name: 'FactAssemblerService', role: 'READ', desc: 'Queries facts for each application', color: 'bg-veridact-review' },
              { layer: 'Layer 2', name: 'PolicyRuleEvaluator', role: 'PURE', desc: 'Zero SOQL. Zero DML. Fully unit-testable.', color: 'bg-veridact-accent' },
              { layer: 'Layer 3', name: 'DecisionCommitService', role: 'WRITE', desc: 'One bulk insert. Append-only. Immutable.', color: 'bg-veridact-approved' },
            ].map((l, i) => (
              <div key={l.name}>
                <div className="flex items-center gap-4 py-4">
                  <div className={`${l.color} text-white text-xs font-semibold px-2 py-1 rounded`}>{l.role}</div>
                  <div>
                    <p className="font-semibold text-sm">{l.name}</p>
                    <p className="text-veridact-fg-muted text-xs">{l.desc}</p>
                  </div>
                </div>
                {i < 2 && (
                  <div className="flex justify-center">
                    <div className="w-px h-6 bg-veridact-border" />
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Stats grid */}
        <div className="grid grid-cols-2 gap-4 mb-8">
          {STATS.map(s => (
            <div key={s.label} className="bg-veridact-card rounded-lg p-4 border border-veridact-border text-center">
              <p className="font-[family-name:var(--font-outfit)] text-2xl font-bold text-veridact-accent">{s.value}</p>
              <p className="text-xs text-veridact-fg-muted mt-1">{s.label}</p>
            </div>
          ))}
        </div>

        {/* Key principles */}
        <div className="space-y-4 mb-8">
          {[
            { title: 'Rules are data, not code', desc: 'Analysts change thresholds through Salesforce records. No deployment needed. Full version history preserved.' },
            { title: 'Every decision is append-only', desc: 'No UPDATE. No DELETE. Enforced by trigger, not convention. A receipt that can be altered is not a receipt.' },
            { title: 'Adverse action with specific reasons', desc: 'ECOA/Reg B compliant. "Your DTI of 43.1% exceeds 43%" — not "failed to meet internal standards."' },
            { title: 'Same kernel, pre-check to decision', desc: 'The soft estimate and the final verdict use identical logic. No divergent math. Honest promises.' },
          ].map(p => (
            <div key={p.title} className="flex gap-3">
              <div className="mt-1.5 w-2 h-2 rounded-full bg-veridact-accent shrink-0" />
              <div>
                <p className="font-semibold text-sm">{p.title}</p>
                <p className="text-veridact-fg-muted text-sm">{p.desc}</p>
              </div>
            </div>
          ))}
        </div>

        <div className="bg-veridact-card rounded-lg p-4 border border-veridact-border text-center text-sm text-veridact-fg-muted mb-8">
          Built on Salesforce Experience Cloud + Apex + LWC. Governed by Allura.
        </div>

        <div className="flex flex-col items-center gap-3">
          <CtaButton href="/contact">Get in touch</CtaButton>
          <a href="/scenarios" className="text-sm text-veridact-fg-muted underline underline-offset-4">
            Run all 5 demo scenarios
          </a>
        </div>
      </div>
      <AccentBar />
    </main>
  );
}
