import { getAuditCases } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { MetricCard } from "@/components/MetricCard";
import { AuditQueueTable } from "@/components/AuditQueueTable";
import { Term } from "@/components/Term";
import { CURRENT_USER } from "@/lib/roles";

export default async function AuditQueuePage() {
  const cases = await getAuditCases();

  const assignedToMe = cases.filter((c) => c.assignedAuditor === CURRENT_USER && c.state !== "Closed").length;
  const highRisk = cases.filter((c) => (c.risk === "High" || c.risk === "Critical") && c.state !== "Closed").length;
  const evidenceNeeded = cases.filter((c) => c.state === "Evidence Needed").length;
  const readyForSignoff = cases.filter((c) => c.state === "Ready for Sign-off").length;
  const slaAtRisk = cases.filter((c) => c.slaStatus !== "On Track" && c.state !== "Closed").length;

  return (
    <main className="p-8">
      <PageHeader
        title="Audit Queue"
        subtitle={
          <>
            Review and <Term>triage</Term> assigned mortgage audits. Filter by
            risk, state, branch, approver, and <Term>SLA</Term>.
          </>
        }
      />

      <div className="mt-6 grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-5">
        <MetricCard value={assignedToMe} label="Assigned to me" accent="primary" />
        <MetricCard value={highRisk} label="High risk" accent="brand-red" />
        <MetricCard value={evidenceNeeded} label="Evidence needed" accent="brand-amber" />
        <MetricCard value={readyForSignoff} label="Ready for sign-off" accent="brand-green" />
        <MetricCard value={slaAtRisk} label="SLA at risk" accent="brand-blue" />
      </div>

      <div className="mt-8">
        <AuditQueueTable cases={cases} />
      </div>
    </main>
  );
}
