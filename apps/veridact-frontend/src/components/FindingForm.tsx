"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

const field = "w-full rounded-[10px] border border-line bg-white px-3 py-2.5 text-sm text-ink focus:border-primary focus:outline-none";
const labelCls = "block text-[13px] font-semibold text-ink";

export function FindingForm({ caseId, loanNumber }: { caseId: string; loanNumber: string }) {
  const router = useRouter();
  const [severity, setSeverity] = useState<"Exception" | "Violation">("Violation");
  const [validUnderPolicy, setValidUnderPolicy] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  function submit(e: React.FormEvent) {
    e.preventDefault();
    // Mock persist. Real call: POST /api/findings then revalidate.
    setSubmitted(true);
  }

  if (submitted) {
    return (
      <div className="rounded-[18px] border border-brand-green/40 bg-chip-green-bg p-6">
        <h2 className="font-display text-[20px] font-bold text-chip-green-fg">Finding recorded</h2>
        <p className="mt-1 text-sm text-chip-green-fg">
          The finding is attached to {loanNumber} and will appear on the sign-off receipt.
        </p>
        <div className="mt-4 flex gap-3">
          <button onClick={() => router.push(`/cases/${caseId}`)} className="rounded-full bg-ink px-5 py-2.5 text-sm font-semibold text-white">
            Back to case
          </button>
          <button onClick={() => router.push("/findings")} className="rounded-full border border-line bg-white px-5 py-2.5 text-sm font-semibold text-ink">
            View all findings
          </button>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="rounded-[18px] border border-line bg-white p-6">
      <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
        <div>
          <label className={labelCls} htmlFor="rule">Rule / check</label>
          <input id="rule" required defaultValue="LTV limit" className={`mt-1 ${field}`} />
        </div>
        <div>
          <label className={labelCls} htmlFor="severity">Severity</label>
          <select id="severity" value={severity} onChange={(e) => setSeverity(e.target.value as "Exception" | "Violation")} className={`mt-1 ${field}`}>
            <option>Exception</option>
            <option>Violation</option>
          </select>
        </div>
        <div className="md:col-span-2">
          <label className={labelCls} htmlFor="guideline">Guideline breached</label>
          <input id="guideline" required placeholder="e.g. Lending Policy v3.1 §4.2 — Max LTV 85%" className={`mt-1 ${field}`} />
        </div>
        <div className="md:col-span-2">
          <label className={labelCls} htmlFor="exemption">Exemption granted</label>
          <input id="exemption" required placeholder="e.g. 7-point LTV overage waived at underwriting" className={`mt-1 ${field}`} />
        </div>
        <div>
          <label className={labelCls} htmlFor="approver">Approved by</label>
          <input id="approver" required placeholder="e.g. M. Carter" className={`mt-1 ${field}`} />
        </div>
        <div className="flex items-end">
          <label className="flex items-center gap-2 text-sm text-ink">
            <input type="checkbox" checked={validUnderPolicy} onChange={(e) => setValidUnderPolicy(e.target.checked)} />
            Exemption was valid under the policy in force
          </label>
        </div>
        <div className="md:col-span-2">
          <label className={labelCls} htmlFor="summary">Summary</label>
          <textarea id="summary" required rows={4} placeholder="What happened and why it is or isn't compliant." className={`mt-1 ${field}`} />
        </div>
      </div>

      {!validUnderPolicy ? (
        <p className="mt-4 rounded-[10px] bg-chip-red-bg px-4 py-2.5 text-[13px] font-medium text-chip-red-fg">
          Flagged: an invalid exemption is the core thing this audit exists to catch.
        </p>
      ) : null}

      <div className="mt-6 flex gap-3">
        <button type="submit" className="rounded-full bg-primary px-6 py-3 text-sm font-semibold text-white hover:opacity-90">
          Record finding
        </button>
        <button type="button" onClick={() => router.push(`/cases/${caseId}`)} className="rounded-full border border-line bg-white px-6 py-3 text-sm font-semibold text-ink">
          Cancel
        </button>
      </div>
    </form>
  );
}
