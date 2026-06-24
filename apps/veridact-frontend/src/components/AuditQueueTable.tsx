"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import type { AuditCase, Risk, CaseState } from "@/lib/types";
import { RiskBadge } from "./RiskBadge";
import { StateBadge, SlaBadge } from "./StateBadge";

type SortKey = "loanNumber" | "borrower" | "risk" | "state" | "originalApprover" | "dueInDays";

const RISK_ORDER: Record<Risk, number> = { Critical: 0, High: 1, Medium: 2, Low: 3 };

function downloadCsv(rows: AuditCase[]) {
  const header = [
    "Loan", "Borrower", "Branch", "Product", "Risk", "State",
    "Approver", "Auditor", "Exceptions", "Violations", "DueInDays",
  ];
  const escape = (v: string | number) => `"${String(v).replace(/"/g, '""')}"`;
  const body = rows.map((r) =>
    [r.loanNumber, r.borrower, r.branch, r.product, r.risk, r.state,
     r.originalApprover, r.assignedAuditor, r.exceptionCount, r.violationCount, r.dueInDays]
      .map(escape).join(","),
  );
  const csv = [header.map(escape).join(","), ...body].join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `veridact-audit-queue-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

export function AuditQueueTable({ cases }: { cases: AuditCase[] }) {
  const [risk, setRisk] = useState<Risk | "">("");
  const [state, setState] = useState<CaseState | "">("");
  const [approver, setApprover] = useState("");
  const [branch, setBranch] = useState("");
  const [onlyExceptions, setOnlyExceptions] = useState(false);
  const [sortKey, setSortKey] = useState<SortKey>("risk");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("asc");

  const approvers = useMemo(
    () => [...new Set(cases.map((c) => c.originalApprover))].sort(),
    [cases],
  );
  const branches = useMemo(
    () => [...new Set(cases.map((c) => c.branch))].sort(),
    [cases],
  );

  const rows = useMemo(() => {
    const filtered = cases.filter(
      (c) =>
        (!risk || c.risk === risk) &&
        (!state || c.state === state) &&
        (!approver || c.originalApprover === approver) &&
        (!branch || c.branch === branch) &&
        (!onlyExceptions || c.exceptionCount + c.violationCount > 0),
    );
    const dir = sortDir === "asc" ? 1 : -1;
    return [...filtered].sort((a, b) => {
      let cmp = 0;
      if (sortKey === "risk") cmp = RISK_ORDER[a.risk] - RISK_ORDER[b.risk];
      else if (sortKey === "dueInDays") cmp = a.dueInDays - b.dueInDays;
      else cmp = String(a[sortKey]).localeCompare(String(b[sortKey]));
      return cmp * dir;
    });
  }, [cases, risk, state, approver, branch, onlyExceptions, sortKey, sortDir]);

  function toggleSort(key: SortKey) {
    if (sortKey === key) setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    else { setSortKey(key); setSortDir("asc"); }
  }

  const selectCls =
    "rounded-full border border-line bg-white px-3 py-2 text-[13px] text-ink";

  return (
    <div>
      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <select className={selectCls} value={risk} onChange={(e) => setRisk(e.target.value as Risk | "")}>
          <option value="">All risk tiers</option>
          <option>Critical</option><option>High</option><option>Medium</option><option>Low</option>
        </select>
        <select className={selectCls} value={state} onChange={(e) => setState(e.target.value as CaseState | "")}>
          <option value="">All states</option>
          <option>In Review</option><option>Evidence Needed</option><option>Ready for Sign-off</option><option>Closed</option>
        </select>
        <select className={selectCls} value={approver} onChange={(e) => setApprover(e.target.value)}>
          <option value="">All approvers</option>
          {approvers.map((a) => <option key={a}>{a}</option>)}
        </select>
        <select className={selectCls} value={branch} onChange={(e) => setBranch(e.target.value)}>
          <option value="">All branches</option>
          {branches.map((b) => <option key={b}>{b}</option>)}
        </select>
        <label className="flex items-center gap-2 text-[13px] text-ink">
          <input type="checkbox" checked={onlyExceptions} onChange={(e) => setOnlyExceptions(e.target.checked)} />
          Exceptions only
        </label>
        <button
          onClick={() => downloadCsv(rows)}
          className="ml-auto rounded-full border border-line bg-white px-4 py-2 text-[13px] font-semibold text-ink hover:bg-peach"
        >
          Export CSV
        </button>
      </div>

      {/* Table */}
      <div className="mt-4 overflow-x-auto rounded-[16px] border border-line bg-white">
        <table className="w-full min-w-[760px] border-collapse text-left text-sm">
          <thead>
            <tr className="border-b border-line bg-surface-head text-[12px] uppercase tracking-wide text-muted">
              <Th label="Loan" onClick={() => toggleSort("loanNumber")} active={sortKey === "loanNumber"} dir={sortDir} />
              <Th label="Borrower" onClick={() => toggleSort("borrower")} active={sortKey === "borrower"} dir={sortDir} />
              <Th label="Risk" onClick={() => toggleSort("risk")} active={sortKey === "risk"} dir={sortDir} />
              <Th label="State" onClick={() => toggleSort("state")} active={sortKey === "state"} dir={sortDir} />
              <th className="px-4 py-3 font-semibold">Exceptions</th>
              <Th label="Approver" onClick={() => toggleSort("originalApprover")} active={sortKey === "originalApprover"} dir={sortDir} />
              <Th label="SLA" onClick={() => toggleSort("dueInDays")} active={sortKey === "dueInDays"} dir={sortDir} />
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {rows.map((c) => (
              <tr
                key={c.id}
                className="border-b border-line/60 last:border-0 hover:bg-peach/40 focus-within:bg-peach/40"
              >
                <td className="px-4 py-3 font-medium text-ink">
                  {/* The loan number is the row's primary link — keyboard reachable. */}
                  <Link
                    href={`/cases/${c.id}`}
                    className="rounded outline-none hover:underline focus-visible:ring-2 focus-visible:ring-primary"
                    aria-label={`Open audit case ${c.loanNumber} — ${c.borrower}`}
                  >
                    {c.loanNumber}
                  </Link>
                </td>
                <td className="px-4 py-3 text-ink">{c.borrower}</td>
                <td className="px-4 py-3"><RiskBadge risk={c.risk} /></td>
                <td className="px-4 py-3"><StateBadge state={c.state} /></td>
                <td className="px-4 py-3">
                  {c.violationCount > 0 ? (
                    <span className="font-semibold text-chip-red-fg">{c.violationCount} violation{c.violationCount > 1 ? "s" : ""}</span>
                  ) : c.exceptionCount > 0 ? (
                    <span className="font-semibold text-chip-amber-fg">{c.exceptionCount} exception{c.exceptionCount > 1 ? "s" : ""}</span>
                  ) : (
                    <span className="text-muted">None</span>
                  )}
                </td>
                <td className="px-4 py-3 text-ink">{c.originalApprover}</td>
                <td className="px-4 py-3"><SlaBadge status={c.slaStatus} dueInDays={c.dueInDays} /></td>
                <td className="px-4 py-3 text-right">
                  <Link
                    href={`/cases/${c.id}`}
                    className="inline-block rounded-full bg-primary px-3 py-1.5 text-[12px] font-semibold text-white outline-none hover:opacity-90 focus-visible:ring-2 focus-visible:ring-ink"
                    tabIndex={-1}
                  >
                    Review
                  </Link>
                </td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-10 text-center text-sm text-muted">
                  No cases match these filters. Clear a filter to see more.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <p className="mt-3 text-[12px] text-muted">
        Showing {rows.length} of {cases.length} cases · open a loan number or its Review button to start the case review.
      </p>
    </div>
  );
}

function Th({ label, onClick, active, dir }: { label: string; onClick: () => void; active: boolean; dir: "asc" | "desc" }) {
  const ariaSort = active ? (dir === "asc" ? "ascending" : "descending") : "none";
  const nextDir = active && dir === "asc" ? "descending" : "ascending";
  return (
    <th className="px-4 py-3 font-semibold" aria-sort={ariaSort}>
      <button
        onClick={onClick}
        aria-label={`Sort by ${label}, ${nextDir}`}
        className="inline-flex items-center gap-1 rounded outline-none hover:text-ink focus-visible:ring-2 focus-visible:ring-primary"
      >
        {label}
        <span aria-hidden="true" className="text-[10px]">{active ? (dir === "asc" ? "▲" : "▼") : "↕"}</span>
      </button>
    </th>
  );
}
