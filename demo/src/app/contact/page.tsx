import { AccentBar } from '@/components/veridact/accent-bar';

export default function Contact() {
  return (
    <main className="flex flex-col min-h-dvh">
      <div className="flex-1 flex flex-col items-center justify-center px-6 text-center max-w-md mx-auto">
        <h1 className="font-[family-name:var(--font-outfit)] text-4xl font-bold leading-tight mb-2">
          Ready for your audit.
        </h1>
        <p className="text-veridact-fg-muted mb-8">
          Built by Allura. Powered by Salesforce.
        </p>
        <div className="bg-veridact-card rounded-lg p-6 border border-veridact-border w-full text-left space-y-3 mb-8">
          <div>
            <p className="text-xs text-veridact-fg-muted uppercase tracking-wide">Contact</p>
            <p className="font-medium">Sabir Asheed</p>
            <p className="text-sm text-veridact-fg-muted">sasheed72@gmail.com</p>
          </div>
          <div>
            <p className="text-xs text-veridact-fg-muted uppercase tracking-wide">Project</p>
            <p className="font-medium">Mortagate — Mortgage Approval Engine</p>
          </div>
        </div>
        <div className="flex flex-col gap-3 w-full">
          <a href="/" className="text-sm text-veridact-fg-muted underline underline-offset-4">Back to start</a>
          <a href="/scenarios" className="text-sm text-veridact-fg-muted underline underline-offset-4">Run demo scenarios</a>
        </div>
      </div>
      <AccentBar />
    </main>
  );
}
