import Link from "next/link";
import { getFindings, getAuditCases } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { SeverityBadge } from "@/components/SeverityBadge";

export default async function FindingsPage() {
  const [findings, cases] = await Promise.all([getFindings(), getAuditCases()]);
  const caseById = new Map(cases.map((c) => [c.id, c]));

  return (
    <main className="p-8">
      <PageHeader title="Findings" subtitle="Every documented exception and guideline violation across cases." />

      <div className="mt-6 space-y-3">
        {findings.length === 0 ? (
          <p className="rounded-[14px] border border-line bg-white p-6 text-sm text-muted">
            No findings recorded yet. Open a case and create one from the replay checks.
          </p>
        ) : (
          findings.map((f) => {
            const c = caseById.get(f.caseId);
            return (
              <Link
                key={f.id}
                href={`/findings/${f.id}`}
                className="block rounded-[14px] border border-line bg-white p-5 hover:bg-peach/40"
              >
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <span className="font-display text-[17px] font-bold text-ink">{f.rule}</span>
                    <span className="ml-3 text-[13px] text-muted">{c?.loanNumber} · {c?.borrower}</span>
                  </div>
                  <SeverityBadge severity={f.severity} />
                </div>
                <p className="mt-2 text-[13px] text-muted">{f.summary}</p>
                {!f.validUnderPolicy ? (
                  <p className="mt-2 text-[12px] font-semibold text-brand-red">Invalid exemption — {f.guidelineRef}</p>
                ) : null}
              </Link>
            );
          })
        )}
      </div>
    </main>
  );
}
