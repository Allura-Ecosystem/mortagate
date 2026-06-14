import { AccentBar } from '@/components/veridact/accent-bar';
import { StatusChip } from '@/components/veridact/status-chip';
import { PERSONAS } from '@/engine/personas';
import { formatCurrency, formatPercent } from '@/lib/utils';

export default function Scenarios() {
  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 px-6 py-12 max-w-2xl mx-auto w-full">
        <h1 className="font-[family-name:var(--font-outfit)] text-3xl font-bold text-center mb-2">
          Demo Scenarios
        </h1>
        <p className="text-center text-veridact-fg-muted mb-8">
          5 borrowers. 7 rules. Every verdict computed live.
        </p>

        <div className="space-y-4">
          {PERSONAS.map(p => (
            <a key={p.id} href={`/scenarios/${p.id}`} className="block bg-veridact-card rounded-lg p-5 border border-veridact-border hover:border-veridact-accent transition-colors">
              <div className="flex items-start justify-between mb-3">
                <h2 className="font-semibold">{p.name}</h2>
                <StatusChip verdict={p.expectedVerdict} />
              </div>
              <div className="grid grid-cols-3 gap-2 text-sm mb-3">
                <div><span className="text-veridact-fg-muted text-xs">FICO</span><p className="font-medium">{p.fico}</p></div>
                <div><span className="text-veridact-fg-muted text-xs">DTI</span><p className="font-medium">{formatPercent(p.dti)}</p></div>
                <div><span className="text-veridact-fg-muted text-xs">Income</span><p className="font-medium">{formatCurrency(p.annualIncome)}</p></div>
              </div>
              <p className="text-sm text-veridact-fg-muted">{p.story}</p>
            </a>
          ))}
        </div>

        <div className="text-center mt-8">
          <a href="/" className="text-sm text-veridact-fg-muted underline underline-offset-4">Back to start</a>
        </div>
      </div>
      <AccentBar />
    </main>
  );
}
