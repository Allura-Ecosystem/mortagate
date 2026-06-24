import Link from "next/link";
import { getReceipts } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";

const outcomeClasses: Record<string, string> = {
  Cleared: "bg-chip-green-bg text-chip-green-fg",
  "Exceptions noted": "bg-chip-amber-bg text-chip-amber-fg",
  "Violations found": "bg-chip-red-bg text-chip-red-fg",
};

export default async function ReceiptsPage() {
  const receipts = await getReceipts();

  return (
    <main className="p-8">
      <PageHeader
        title="Sign-off receipts"
        subtitle="Sealed, tamper-evident records. Once signed, a receipt cannot be edited — corrections are appended as notes."
      />

      <div className="mt-6 space-y-3">
        {receipts.length === 0 ? (
          <p className="rounded-[14px] border border-line bg-white p-6 text-sm text-muted">
            No receipts yet. A receipt is created when a reviewer seals a case.
          </p>
        ) : (
          receipts.map((r) => (
            <Link
              key={r.id}
              href={`/receipts/${r.id}`}
              className="block rounded-[14px] border border-line bg-white p-5 hover:bg-peach/40"
            >
              <div className="flex items-center justify-between gap-4">
                <div>
                  <span className="font-display text-[17px] font-bold text-ink">{r.id}</span>
                  <span className="ml-3 text-[13px] text-muted">
                    {r.loanNumber} · sealed by {r.reviewer}
                  </span>
                </div>
                <span
                  className={`rounded-full px-3 py-1 text-[12px] font-semibold ${
                    outcomeClasses[r.outcome] ?? "bg-peach text-ink"
                  }`}
                >
                  {r.outcome}
                </span>
              </div>
              <p className="mt-2 text-[12px] text-muted">
                Signed {new Date(r.signedAt).toLocaleString()} · hash {r.hash}
              </p>
            </Link>
          ))
        )}
      </div>
    </main>
  );
}
