import { getPolicyVersions } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";

export default async function PolicyPage() {
  const versions = await getPolicyVersions();

  return (
    <main className="p-8">
      <PageHeader
        title="Policy versions"
        subtitle="The rulebook a loan is judged against is the one in force on its approval date — not today's."
      />

      <div className="mt-6 overflow-hidden rounded-[18px] border border-line bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-line bg-surface text-left text-[12px] uppercase tracking-wide text-muted">
              <th className="px-5 py-3">Version</th>
              <th className="px-5 py-3">Effective from</th>
              <th className="px-5 py-3">Effective to</th>
              <th className="px-5 py-3">Max DTI</th>
              <th className="px-5 py-3">Max LTV</th>
              <th className="px-5 py-3">Min credit</th>
              <th className="px-5 py-3">Status</th>
            </tr>
          </thead>
          <tbody>
            {versions.map((p) => {
              const current = p.effectiveTo === null;
              return (
                <tr key={p.id} className="border-b border-line last:border-0">
                  <td className="px-5 py-3 font-semibold text-ink">{p.label}</td>
                  <td className="px-5 py-3 text-ink">{p.effectiveFrom}</td>
                  <td className="px-5 py-3 text-ink">{p.effectiveTo ?? "—"}</td>
                  <td className="px-5 py-3 text-ink">{p.dtiCap}%</td>
                  <td className="px-5 py-3 text-ink">{p.ltvCap}%</td>
                  <td className="px-5 py-3 text-ink">{p.minCreditScore}</td>
                  <td className="px-5 py-3">
                    <span
                      className={`rounded-full px-3 py-1 text-[12px] font-semibold ${
                        current
                          ? "bg-chip-green-bg text-chip-green-fg"
                          : "bg-chip-neutral-bg text-chip-neutral-fg"
                      }`}
                    >
                      {current ? "Current" : "Superseded"}
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <p className="mt-4 text-[12px] text-muted">
        Policy versions are read-only here. Editing the rulebook is an Admin action and is
        logged as its own receipt.
      </p>
    </main>
  );
}
