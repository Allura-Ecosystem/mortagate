import { CtaButton } from '@/components/veridact/cta-button';
import { AccentBar } from '@/components/veridact/accent-bar';

export default function Landing() {
  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 flex flex-col items-center justify-center px-6 text-center max-w-md mx-auto">
        <h1 className="font-[family-name:var(--font-outfit)] text-5xl md:text-7xl font-bold leading-[1.1] mb-4">
          Veridact
        </h1>
        <p className="text-veridact-fg-muted text-lg mb-2">
          Mortgage audit intelligence by Allura
        </p>
        <p className="font-[family-name:var(--font-outfit)] text-veridact-fg-muted text-base mb-12 opacity-60">
          Every decision has a receipt.
        </p>
        <CtaButton href="/journey">See how it works</CtaButton>

        <div className="mt-16 flex items-center gap-4">
          {[
            { label: 'Cream', color: '#F5F0E8', border: true },
            { label: 'Charcoal', color: '#1F1E1C', border: false },
            { label: 'Orange', color: '#E25D22', border: false },
            { label: 'Approval', color: '#308357', border: false },
          ].map(t => (
            <div key={t.label} className="flex items-center gap-1.5">
              <div
                className="w-3 h-3 rounded-sm"
                style={{ background: t.color, border: t.border ? '1px solid #D7CCBB' : 'none' }}
              />
              <span className="text-xs text-veridact-fg-muted">{t.label}</span>
            </div>
          ))}
        </div>
      </div>
      <AccentBar />
    </main>
  );
}
