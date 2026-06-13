// Mock API layer. Every function is async so the swap to a real
// fetch('/api/...') later is a one-line change per call site.

import {
  auditCases,
  replayChecks,
  evidenceItems,
  findings,
  receipts,
  policyVersions,
} from "./mock";
import type {
  AuditCase,
  ReplayCheck,
  EvidenceItem,
  Finding,
  AuditReceipt,
  PolicyVersion,
  Analytics,
} from "./types";

const clone = <T,>(v: T): T => JSON.parse(JSON.stringify(v));

export async function getAuditCases(): Promise<AuditCase[]> {
  return clone(auditCases);
}

export async function getAuditCase(id: string): Promise<AuditCase | undefined> {
  return clone(auditCases.find((c) => c.id === id || c.loanNumber === id));
}

export async function getReplayChecks(caseId: string): Promise<ReplayCheck[]> {
  const own = replayChecks.filter((c) => c.caseId === caseId);
  if (own.length) return clone(own);
  // Clean default for cases without a hand-authored set.
  return [
    { id: `${caseId}-d1`, caseId, ruleId: "dti-threshold", ruleName: "DTI threshold", detail: "Within policy cap", status: "Pass", evidenceIds: [], rationaleRequired: false },
    { id: `${caseId}-d2`, caseId, ruleId: "ltv-limit", ruleName: "LTV limit", detail: "Within policy cap", status: "Pass", evidenceIds: [], rationaleRequired: false },
    { id: `${caseId}-d3`, caseId, ruleId: "income-verified", ruleName: "Income verified", detail: "Documents on file", status: "Pass", evidenceIds: [], rationaleRequired: false },
    { id: `${caseId}-d4`, caseId, ruleId: "appraisal-complete", ruleName: "Appraisal complete", detail: "Report present", status: "Pass", evidenceIds: [], rationaleRequired: false },
    { id: `${caseId}-d5`, caseId, ruleId: "exception-approval", ruleName: "Exception approval", detail: "No exceptions on file", status: "Pass", evidenceIds: [], rationaleRequired: false },
  ];
}

export async function getEvidence(caseId: string): Promise<EvidenceItem[]> {
  const own = evidenceItems.filter((e) => e.caseId === caseId);
  if (own.length) return clone(own);
  return [
    { id: `${caseId}-ev1`, caseId, label: "Form 1040", kind: "Tax return", status: "Linked" },
    { id: `${caseId}-ev2`, caseId, label: "W-2", kind: "Income", status: "Linked" },
    { id: `${caseId}-ev3`, caseId, label: "Appraisal report", kind: "Appraisal", status: "Linked" },
    { id: `${caseId}-ev4`, caseId, label: "Credit report", kind: "Credit", status: "Linked" },
  ];
}

export async function getFindings(caseId?: string): Promise<Finding[]> {
  const list = caseId ? findings.filter((f) => f.caseId === caseId) : findings;
  return clone(list);
}

export async function getFinding(id: string): Promise<Finding | undefined> {
  return clone(findings.find((f) => f.id === id));
}

export async function getReceipts(): Promise<AuditReceipt[]> {
  return clone(receipts);
}

export async function getReceipt(id: string): Promise<AuditReceipt | undefined> {
  return clone(receipts.find((r) => r.id === id || r.caseId === id));
}

export async function getPolicyVersions(): Promise<PolicyVersion[]> {
  return clone(policyVersions);
}

export async function getPolicyVersion(id: string): Promise<PolicyVersion | undefined> {
  return clone(policyVersions.find((p) => p.id === id));
}

export async function getAnalytics(): Promise<Analytics> {
  const cases = auditCases;
  const total = cases.length;
  const withException = cases.filter((c) => c.exceptionCount > 0).length;
  const withViolation = cases.filter((c) => c.violationCount > 0).length;

  const unverifiable = replayChecks.filter((c) => c.status === "Unverifiable").length;
  const totalChecks = replayChecks.length || 1;
  const missingEvidence = evidenceItems.filter(
    (e) => e.status === "Missing" || e.status === "Expired" || e.status === "Contradictory" || e.status === "Mismatch",
  ).length;

  const byApprover = new Map<string, { ex: number; n: number }>();
  for (const c of cases) {
    const a = byApprover.get(c.originalApprover) ?? { ex: 0, n: 0 };
    a.n += 1;
    if (c.exceptionCount + c.violationCount > 0) a.ex += 1;
    byApprover.set(c.originalApprover, a);
  }

  const byBranch = new Map<string, { high: number; n: number }>();
  for (const c of cases) {
    const b = byBranch.get(c.branch) ?? { high: 0, n: 0 };
    b.n += 1;
    if (c.risk === "High" || c.risk === "Critical") b.high += 1;
    byBranch.set(c.branch, b);
  }

  const byPolicy = new Map<string, { fail: number; n: number }>();
  for (const c of cases) {
    const p = byPolicy.get(c.policyVersionId) ?? { fail: 0, n: 0 };
    p.n += 1;
    if (c.violationCount > 0) p.fail += 1;
    byPolicy.set(c.policyVersionId, p);
  }

  return {
    totalCases: total,
    exceptionRate: withException / total,
    violationRate: withViolation / total,
    unverifiableRate: unverifiable / totalChecks,
    missingEvidenceCount: missingEvidence,
    slaAtRisk: cases.filter((c) => c.slaStatus !== "On Track").length,
    approverDrift: [...byApprover.entries()]
      .map(([approver, v]) => ({ approver, exceptionRate: v.ex / v.n, cases: v.n }))
      .sort((a, b) => b.exceptionRate - a.exceptionRate),
    branchRisk: [...byBranch.entries()]
      .map(([branch, v]) => ({ branch, highRiskShare: v.high / v.n }))
      .sort((a, b) => b.highRiskShare - a.highRiskShare),
    policyFailure: [...byPolicy.entries()]
      .map(([policy, v]) => ({ policy, failureRate: v.fail / v.n }))
      .sort((a, b) => b.failureRate - a.failureRate),
  };
}
