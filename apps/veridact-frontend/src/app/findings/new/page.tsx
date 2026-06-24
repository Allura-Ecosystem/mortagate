import Link from "next/link";
import { getAuditCase } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { FindingForm } from "@/components/FindingForm";

export default async function NewFindingPage({
  searchParams,
}: {
  searchParams: Promise<{ caseId?: string }>;
}) {
  const { caseId } = await searchParams;
  const auditCase = caseId ? await getAuditCase(caseId) : undefined;

  return (
    <main className="p-8">
      {auditCase ? (
        <Link href={`/cases/${auditCase.id}`} className="text-[13px] font-medium text-muted hover:text-ink">
          ← Back to {auditCase.loanNumber}
        </Link>
      ) : null}
      <div className="mt-2">
        <PageHeader
          title="New finding"
          subtitle={auditCase ? `Documenting a finding on ${auditCase.loanNumber} — ${auditCase.borrower}` : "Document a finding."}
        />
      </div>
      <div className="mt-6 max-w-3xl">
        <FindingForm caseId={auditCase?.id ?? ""} loanNumber={auditCase?.loanNumber ?? "this case"} />
      </div>
    </main>
  );
}
