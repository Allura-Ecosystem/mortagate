'use client';

import { useState } from 'react';
import { AccentBar } from '@/components/veridact/accent-bar';
import { CtaButton } from '@/components/veridact/cta-button';
import { StatusChip } from '@/components/veridact/status-chip';
import { preFlightEvaluate } from '@/engine/evaluator';
import { formatCurrency } from '@/lib/utils';

const DEMO_INCOME = 80000;
const DEMO_PROPERTY = 425000;

const TIMELINE_EVENTS = [
  { label: 'Application received', delay: 0 },
  { label: 'Documents uploaded', delay: 600 },
  { label: 'Income verified', delay: 1200 },
  { label: 'Underwriting review started', delay: 1800 },
  { label: 'Decision rendered', delay: 2400 },
];

export default function Journey() {
  const [screen, setScreen] = useState(0);
  const [timelineIndex, setTimelineIndex] = useState(-1);

  const band = preFlightEvaluate(DEMO_INCOME, DEMO_PROPERTY);
  const next = () => {
    const nextScreen = screen + 1;
    setScreen(nextScreen);
    if (nextScreen === 4) {
      // Auto-populate timeline events
      TIMELINE_EVENTS.forEach((_, i) => {
        setTimeout(() => setTimelineIndex(i), TIMELINE_EVENTS[i].delay);
      });
      // Auto-advance to outcome after timeline completes
      setTimeout(() => setScreen(5), 3200);
    }
  };

  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 flex flex-col items-center justify-center px-6 text-center max-w-md mx-auto w-full">

        {/* Screen 1: Welcome */}
        {screen === 0 && (
          <div className="flex flex-col items-center gap-4">
            <h1 className="font-[family-name:var(--font-outfit)] text-3xl font-semibold leading-tight">
              Let&rsquo;s find out what you qualify for.
            </h1>
            <p className="text-veridact-fg-muted">Takes about 8 minutes. No account needed to start.</p>
            <CtaButton onClick={next} className="mt-4">Get Started</CtaButton>
            <p className="font-[family-name:var(--font-outfit)] text-veridact-fg-muted text-sm mt-8 opacity-60">
              Every decision has a receipt.
            </p>
          </div>
        )}

        {/* Screen 2: Intent (pre-filled for demo) */}
        {screen === 1 && (
          <div className="flex flex-col items-center gap-6 w-full">
            <p className="text-xs text-veridact-fg-muted tracking-wide uppercase">Demo — pre-filled data</p>
            <h2 className="font-[family-name:var(--font-outfit)] text-2xl font-semibold">Buying a home</h2>
            <div className="w-full space-y-4 text-left">
              <div className="flex justify-between py-3 border-b border-veridact-border">
                <span className="text-veridact-fg-muted">Property value</span>
                <span className="font-medium">{formatCurrency(DEMO_PROPERTY)}</span>
              </div>
              <div className="flex justify-between py-3 border-b border-veridact-border">
                <span className="text-veridact-fg-muted">Annual income</span>
                <span className="font-medium">{formatCurrency(DEMO_INCOME)}</span>
              </div>
            </div>
            <CtaButton onClick={next} className="mt-4">See my range</CtaButton>
          </div>
        )}

        {/* Screen 3: Pre-Check */}
        {screen === 2 && (
          <div className="flex flex-col items-center gap-4">
            <StatusChip verdict="APPROVED" />
            <p className="font-[family-name:var(--font-outfit)] text-4xl font-semibold text-veridact-approved">
              {formatCurrency(band.lowEstimate)} &ndash; {formatCurrency(band.highEstimate)}
            </p>
            <p className="text-veridact-fg-muted max-w-xs">{band.guidance}</p>
            <div className="mt-6 w-full max-w-xs">
              <p className="text-sm text-veridact-fg-muted mb-2">Ready to apply? Enter your email to continue.</p>
              <div className="flex flex-col gap-3">
                <input
                  type="email"
                  placeholder="you@example.com"
                  defaultValue="demo@veridact.com"
                  className="w-full px-4 py-3 rounded-lg border border-veridact-border bg-transparent text-veridact-fg"
                  readOnly
                />
                <CtaButton onClick={next}>Continue</CtaButton>
              </div>
            </div>
          </div>
        )}

        {/* Screen 4: Evidence Queue */}
        {screen === 3 && (
          <div className="flex flex-col items-center gap-4">
            <p className="text-xs text-veridact-fg-muted tracking-wide">Document 1 of 4</p>
            <h2 className="font-[family-name:var(--font-outfit)] text-2xl font-semibold">
              Upload your most recent pay stub.
            </h2>
            <div className="w-full max-w-xs border-2 border-dashed border-veridact-border rounded-lg p-8 mt-4">
              <p className="text-veridact-fg-muted text-sm">Drag and drop, or choose a file</p>
            </div>
            <p className="text-veridact-approved font-semibold mt-2">
              Got it. That&rsquo;s the hardest one.
            </p>
            <CtaButton onClick={next} className="mt-4">Continue</CtaButton>
          </div>
        )}

        {/* Screen 5: Decision Room */}
        {screen === 4 && (
          <div className="flex flex-col items-center gap-6 w-full">
            <div className="w-4 h-4 rounded-full bg-veridact-accent pulse" />
            <p className="text-veridact-fg-muted max-w-[28ch]">
              Your file is under review. This timeline updates in real time.
            </p>
            <ul className="w-full max-w-xs space-y-0 text-left mt-4">
              {TIMELINE_EVENTS.map((evt, i) => (
                <li
                  key={evt.label}
                  className={`flex items-start gap-3 py-2 transition-opacity duration-500 ${i <= timelineIndex ? 'opacity-100' : 'opacity-0'}`}
                >
                  <div className="mt-1.5 w-3 h-3 rounded-full bg-veridact-accent shrink-0" />
                  <span className="text-sm">{evt.label}</span>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Screen 6: Outcome */}
        {screen === 5 && (
          <div className="flex flex-col items-center gap-4">
            <StatusChip verdict="APPROVED" />
            <h1 className="font-[family-name:var(--font-outfit)] text-3xl font-semibold">
              You&rsquo;re approved.
            </h1>
            <p className="font-[family-name:var(--font-outfit)] text-4xl font-semibold text-veridact-approved">
              {formatCurrency(band.highEstimate)}
            </p>
            <p className="text-veridact-fg-muted text-sm">Estimated rate: 7.0%</p>
            <CtaButton onClick={() => window.location.href = '/audit-gap'} className="mt-4">
              See the audit gap
            </CtaButton>
            <a href="/receipt/karim" className="text-sm text-veridact-fg-muted underline underline-offset-4 mt-2">
              View your decision receipt
            </a>
          </div>
        )}
      </div>

      {/* Navigation footer */}
      {screen < 5 && screen > 0 && screen !== 4 && (
        <div className="px-6 py-4 flex justify-between max-w-md mx-auto w-full">
          <button onClick={() => setScreen(s => s - 1)} className="text-sm text-veridact-fg-muted">
            &larr; Back
          </button>
          <span className="text-xs text-veridact-fg-muted opacity-50">
            {screen + 1} of 6
          </span>
        </div>
      )}

      <AccentBar />
    </main>
  );
}
