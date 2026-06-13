import { getAnalytics } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { MetricCard } from "@/components/MetricCard";

const pct = (n: number) => `${Math.round(n * 100)}%`;

export default async function AnalyticsPage() {
  const a = await getAnalytics();

  return (
    <main className="p-8">
      <PageHeader
        title="Analytics"
        subtitle="Where the risk is concentrated — by rule, approver, branch, and policy version."
      />

      <div className="mt-6 grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
        <MetricCard value={a.totalCases} label="Cases in scope" accent="brand-blue" />
        <MetricCard value={pct(a.exceptionRate)} label="Exception rate" accent="brand-amber" />
        <MetricCard value={pct(a.violationRate)} label="Violation rate" accent="brand-red" />
        <MetricCard value={pct(a.unverifiableRate)} label="Unverifiable checks" accent="muted" />
        <MetricCard value={a.missingEvidenceCount} label="Evidence problems" accent="primary" />
        <MetricCard value={a.slaAtRisk} label="SLA at risk" accent="brand-red" />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <RankTable
          title="Approver drift"
          help="Which approvers have the most exceptions or violations across their cases."
          rows={a.approverDrift.map((d) => ({
            label: d.approver,
            sub: `${d.cases} case${d.cases === 1 ? "" : "s"}`,
            value: pct(d.exceptionRate),
            hot: d.exceptionRate >= 0.5,
          }))}
        />
        <RankTable
          title="Branch risk"
          help="Share of high or critical risk cases at each branch."
          rows={a.branchRisk.map((d) => ({
            label: d.branch,
            value: pct(d.highRiskShare),
            hot: d.highRiskShare >= 0.5,
          }))}
        />
        <RankTable
          title="Policy version failures"
          help="Violation rate for cases approved under each policy version."
          rows={a.policyFailure.map((d) => ({
            label: d.policy,
            value: pct(d.failureRate),
            hot: d.failureRate >= 0.5,
          }))}
        />
      </div>
    </main>
  );
}

function RankTable({
  title,
  help,
  rows,
}: {
  title: string;
  help: string;
  rows: { label: string; sub?: string; value: string; hot?: boolean }[];
}) {
  return (
    <section className="rounded-[18px] border border-line bg-white p-6">
      <h2 className="font-display text-[18px] font-bold text-ink">{title}</h2>
      <p className="mt-1 text-[12px] text-muted">{help}</p>
      <div className="mt-4 space-y-2">
        {rows.map((r, i) => (
          <div
            key={i}
            className="flex items-center justify-between rounded-[10px] border border-line bg-surface px-3 py-2.5"
          >
            <div>
              <span className="text-[14px] font-medium text-ink">{r.label}</span>
              {r.sub ? <span className="ml-2 text-[12px] text-muted">{r.sub}</span> : null}
            </div>
            <span
              className={`text-[14px] font-bold ${r.hot ? "text-brand-red" : "text-ink"}`}
            >
              {r.value}
            </span>
          </div>
        ))}
      </div>
    </section>
  );
}
