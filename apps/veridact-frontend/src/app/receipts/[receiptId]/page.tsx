import Link from "next/link";
import {
  getReceipt,
  getAuditCase,
  getPolicyVersion,
  getFindings,
} from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { ShieldIcon } from "@/components/ShieldIcon";
import { DemoBadge } from "@/components/DemoBadge";
import { Term } from "@/components/Term";
import { glossFor } from "@/lib/glossary";

const outcomeClasses: Record<string, string> = {
  Cleared: "bg-chip-green-bg text-chip-green-fg",
  "Exceptions noted": "bg-chip-amber-bg text-chip-amber-fg",
  "Violations found": "bg-chip-red-bg text-chip-red-fg",
};

export default async function ReceiptDetailPage({
  params,
}: {
  params: Promise<{ receiptId: string }>;
}) {
  const { receiptId } = await params;
  const receipt = await getReceipt(receiptId);

  // No silent failure: if a case has no sealed receipt yet, say so plainly.
  if (!receipt) {
    const auditCase = await getAuditCase(receiptId);
    return (
      <main className="p-8">
        <Link href="/receipts" className="text-[13px] font-medium text-muted hover:text-ink">
          ← Back to receipts
        </Link>
        <div className="mt-2">
          <PageHeader title="No receipt yet" />
        </div>
        <div className="mt-6 max-w-2xl rounded-[18px] border border-line bg-white p-6">
          <p className="text-sm text-ink">
            {auditCase
              ? `${auditCase.loanNumber} — ${auditCase.borrower} has not been sealed yet. A receipt is created the moment a reviewer signs the case off.`
              : "We could not find a receipt or a case with that reference."}
          </p>
          {auditCase ? (
            <Link
              href={`/cases/${auditCase.id}`}
              className="mt-4 inline-block rounded-full bg-ink px-5 py-2.5 text-sm font-semibold text-white"
            >
              Go to the case
            </Link>
          ) : null}
        </div>
      </main>
    );
  }

  const [auditCase, policy, findings] = await Promise.all([
    getAuditCase(receipt.caseId),
    getPolicyVersion(receipt.policyVersionId),
    getFindings(receipt.caseId),
  ]);

  return (
    <main className="p-8">
      <Link href="/receipts" className="text-[13px] font-medium text-muted hover:text-ink">
        ← Back to receipts
      </Link>
      <div className="mt-2">
        <PageHeader
          title={receipt.id}
          subtitle={`${receipt.loanNumber} · sealed by ${receipt.reviewer}`}
          actions={
            <span
              className={`rounded-full px-3 py-1 text-[12px] font-semibold ${
                outcomeClasses[receipt.outcome] ?? "bg-peach text-ink"
              }`}
            >
              {receipt.outcome}
            </span>
          }
        />
      </div>

      {/* Seal banner — immutability is the whole point. The seal claim and its
          honest caveat live in ONE box so the green never lands a half-second
          before the disclaimer it depends on (Brooke). Wording describes how
          sealing works rather than asserting this demo hash is real crypto. */}
      <div className="mt-4 rounded-[12px] border border-brand-green/40 bg-chip-green-bg px-4 py-3 text-chip-green-fg">
        <div className="flex flex-wrap items-center justify-between gap-3 text-[13px]">
          <span className="inline-flex items-center gap-2 font-semibold">
            <ShieldIcon size={16} className="text-chip-green-fg" title="Sealed receipt" />
            <span>
              <Term define={glossFor("seal")}>Sealed</Term>{" "}
              {new Date(receipt.signedAt).toLocaleString()} — once sealed, the record is
              locked against edits; later corrections are appended below, never overwritten.
            </span>
          </span>
          <span className="font-mono text-[12px]">
            <Term define={glossFor("hash")}>hash</Term> {receipt.hash}
          </span>
        </div>
        {/* Honest disclosure, fused to the seal it qualifies. Full-contrast and
            medium weight so the caveat lands at least as hard as the reassurance
            above it — the honesty is the load-bearing sentence (Brooke + AA contrast). */}
        {/* The honest caveat gets its OWN neutral surface inside the green box —
            a faint border + amber-tinted ground so it reads as a separate
            "read me" note, not part of the green all-clear (Brooke). */}
        <div className="mt-2.5 flex flex-wrap items-center gap-2 rounded-[10px] border border-chip-amber-fg/30 bg-chip-amber-bg px-3 py-2 text-[12px] font-medium text-chip-amber-fg">
          <DemoBadge />
          <span>
            This hash is <span className="font-semibold">illustrative sample data, not a
            cryptographic seal</span> — production computes a SHA-256 digest of the sealed record.
          </span>
        </div>
      </div>

      {/* Trust, spelled out: why "sealed" is more than a label, and how anyone
          could check it for themselves (Brooke). Plain-language, three steps. */}
      <details className="mt-3 max-w-2xl rounded-[12px] border border-line bg-surface px-4 py-3 text-[13px] text-ink">
        <summary className="cursor-pointer font-semibold">
          How this receipt is verified
        </summary>
        <ol className="mt-2 list-decimal space-y-1.5 pl-5 text-muted">
          <li>
            The hash above is a SHA-256 fingerprint of every sealed field — loan,
            reviewer, outcome, policy version, and timestamp.
          </li>
          <li>
            Re-compute the fingerprint and compare it to the stored hash: if a
            single character of the record were changed, the two would not match.
          </li>
          <li>
            The original is never overwritten. Anything learned after sign-off is
            added to the dated Correction log below — so the trail is additive, not
            edited.
          </li>
        </ol>
      </details>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <section className="lg:col-span-2 rounded-[18px] border border-line bg-white p-6">
          <h2 className="font-display text-[18px] font-bold text-ink">What was sealed</h2>
          <dl className="mt-4 grid grid-cols-2 gap-x-6 gap-y-3 text-sm">
            <Row label="Loan" value={receipt.loanNumber} />
            <Row label="Borrower" value={auditCase?.borrower ?? "—"} />
            <Row label="Reviewer" value={receipt.reviewer} />
            <Row label="Policy in force" value={policy?.label ?? receipt.policyVersionId} />
          </dl>

          <h3 className="mt-6 text-[13px] font-semibold uppercase tracking-wide text-muted">
            <Term define={glossFor("finding")}>Findings</Term> on record ({findings.length})
          </h3>
          {findings.length === 0 ? (
            <p className="mt-2 text-sm text-muted">No findings — case cleared on replay.</p>
          ) : (
            <div className="mt-2 space-y-2">
              {findings.map((f) => (
                <Link
                  key={f.id}
                  href={`/findings/${f.id}`}
                  className="block rounded-[12px] border border-line bg-surface p-3 hover:bg-peach/40"
                >
                  <span className="text-[14px] font-semibold text-ink">{f.rule}</span>
                  <span className="ml-2 text-[12px] text-muted">{f.severity}</span>
                </Link>
              ))}
            </div>
          )}
        </section>

        {/* Append-only correction log */}
        <aside className="rounded-[18px] border border-line bg-white p-6">
          <h2 className="font-display text-[18px] font-bold text-ink">Correction log</h2>
          <p className="mt-1 text-[12px] text-muted">
            The receipt is never changed. Anything after sign-off is added here as a dated note.
          </p>
          <div className="mt-4 space-y-3">
            {receipt.notes.length === 0 ? (
              <p className="text-sm text-muted">No corrections appended.</p>
            ) : (
              receipt.notes.map((n, i) => (
                <div key={i} className="rounded-[12px] border border-line bg-surface p-3">
                  <p className="text-[12px] text-muted">
                    {new Date(n.at).toLocaleString()} · {n.by}
                  </p>
                  <p className="mt-1 text-[13px] text-ink">{n.text}</p>
                </div>
              ))
            )}
          </div>
        </aside>
      </div>
    </main>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-[12px] uppercase tracking-wide text-muted">{label}</dt>
      <dd className="mt-0.5 font-medium text-ink">{value}</dd>
    </div>
  );
}
