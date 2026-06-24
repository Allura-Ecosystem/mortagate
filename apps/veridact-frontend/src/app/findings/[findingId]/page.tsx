import Link from "next/link";
import { notFound } from "next/navigation";
import { getFinding, getAuditCase, getPolicyVersion } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { SeverityBadge } from "@/components/SeverityBadge";

export default async function FindingDetailPage({
  params,
}: {
  params: Promise<{ findingId: string }>;
}) {
  const { findingId } = await params;
  const finding = await getFinding(findingId);
  if (!finding) notFound();

  const auditCase = await getAuditCase(finding.caseId);
  const policy = auditCase
    ? await getPolicyVersion(auditCase.policyVersionId)
    : undefined;

  return (
    <main className="p-8">
      <Link href="/findings" className="text-[13px] font-medium text-muted hover:text-ink">
        ← Back to findings
      </Link>
      <div className="mt-2">
        <PageHeader
          title={finding.ruleName}
          subtitle={
            auditCase
              ? `${auditCase.loanNumber} · ${auditCase.borrower} · ${auditCase.branch}`
              : finding.caseId
          }
          actions={<SeverityBadge severity={finding.severity} />}
        />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Main */}
        <section className="lg:col-span-2 rounded-[18px] border border-line bg-white p-6">
          <h2 className="font-display text-[18px] font-bold text-ink">What we found</h2>
          <p className="mt-2 text-sm text-ink">{finding.summary}</p>

          <dl className="mt-6 space-y-4">
            <Row label="Guideline breached" value={finding.guidelineRef} />
            <Row label="Exemption granted" value={finding.exemptionGranted} />
            <Row label="Approved by" value={finding.approvedBy} />
          </dl>

          <div
            className={`mt-6 rounded-[12px] px-4 py-3 text-[13px] font-medium ${
              finding.validUnderPolicy
                ? "bg-chip-green-bg text-chip-green-fg"
                : "bg-chip-red-bg text-chip-red-fg"
            }`}
          >
            {finding.validUnderPolicy
              ? "Valid: the exemption was allowed under the policy in force on the approval date."
              : "Invalid exemption: this waiver was not allowed under the policy in force on the approval date. This is the core thing the audit exists to catch."}
          </div>
        </section>

        {/* Side: policy replay context */}
        <aside className="rounded-[18px] border border-line bg-white p-6">
          <h2 className="font-display text-[18px] font-bold text-ink">Policy in force</h2>
          {policy ? (
            <dl className="mt-3 space-y-3 text-sm">
              <Row label="Policy version" value={policy.label} />
              <Row label="Effective" value={`${policy.effectiveFrom} → ${policy.effectiveTo ?? "current"}`} />
              <Row label="Max DTI" value={`${policy.dtiCap}%`} />
              <Row label="Max LTV" value={`${policy.ltvCap}%`} />
              <Row label="Min credit score" value={String(policy.minCreditScore)} />
            </dl>
          ) : (
            <p className="mt-3 text-sm text-muted">Policy version not on file.</p>
          )}

          <div className="mt-5 border-t border-line pt-4 text-[12px] text-muted">
            <p className="font-semibold uppercase tracking-wide">Audit trail</p>
            <p className="mt-1">
              Raised by {finding.createdBy} on{" "}
              {new Date(finding.createdAt).toLocaleDateString()}.
            </p>
          </div>

          {auditCase ? (
            <Link
              href={`/cases/${auditCase.id}`}
              className="mt-5 block rounded-full border border-line bg-white px-5 py-2.5 text-center text-sm font-semibold text-ink hover:bg-peach/40"
            >
              Open the case
            </Link>
          ) : null}
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
