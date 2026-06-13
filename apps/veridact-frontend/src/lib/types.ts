// Veridact domain types — the execution contract the UI binds to.
// Source of truth: Figma "Veridact UX Flow — Mortgage Audit Replay & QC".

export type Risk = "Low" | "Medium" | "High" | "Critical";

// Locked explicit case states (no vibes-based status jumping).
export type CaseState =
  | "In Review"
  | "Evidence Needed"
  | "Ready for Sign-off"
  | "Closed";

export type SlaStatus = "On Track" | "At Risk" | "Overdue";

// A replay check is one lending rule re-run against the original approval.
export type CheckStatus = "Pass" | "Exception" | "Unverifiable" | "Violation";

// How a piece of evidence stands relative to the rule it should support.
export type EvidenceStatus =
  | "Linked"
  | "Missing"
  | "Contradictory"
  | "Expired"
  | "Mismatch";

export type Role =
  | "Auditor"
  | "Reviewer"
  | "Manager"
  | "Admin"
  | "Compliance Viewer";

export type Sampling = "Random" | "Risk-based" | "Targeted" | "Ad hoc";

export type AuditCase = {
  id: string;
  loanNumber: string;
  borrower: string;
  branch: string;
  product: string;
  risk: Risk;
  state: CaseState;
  assignedAuditor: string;
  originalApprover: string;
  approvalDate: string; // ISO date the original loan was approved
  policyVersionId: string; // policy in force on the approval date
  sampling: Sampling;
  slaStatus: SlaStatus;
  dueInDays: number; // negative = overdue
  exceptionCount: number; // exceptions found on replay
  violationCount: number; // hard guideline violations found
};

export type ReplayCheck = {
  id: string;
  caseId: string;
  rule: string; // e.g. "DTI threshold"
  detail: string; // e.g. "Policy cap 43% · actual 47%"
  status: CheckStatus;
  evidenceIds: string[];
  rationaleRequired: boolean;
  // One-line plain-language reason this check landed where it did — the
  // manager's stated justification for an exception, or why a rule was
  // judged broken/unverifiable. Shown inline so a reviewer doesn't have to
  // open the finding just to see the gist. Full text lives on the finding.
  rationale?: string;
};

export type EvidenceItem = {
  id: string;
  caseId: string;
  label: string; // e.g. "Form 1040 — 2023"
  kind: string; // e.g. "Tax return", "Appraisal", "Credit report"
  status: EvidenceStatus;
  note?: string;
};

export type Finding = {
  id: string;
  caseId: string;
  rule: string;
  severity: "Exception" | "Violation";
  summary: string;
  guidelineRef: string; // the lending guideline that was breached
  exemptionGranted: string; // what the approver waived
  approvedBy: string; // who granted the exemption
  validUnderPolicy: boolean; // was that exemption allowed under the policy then?
  createdBy: string;
  createdAt: string;
};

// Append-only, immutable after sign-off. Corrections add a new note, never edit.
export type ReceiptNote = {
  readonly at: string;
  readonly by: string;
  readonly text: string;
};

// `readonly` on every field is intentional: once sealed, a receipt is a fact,
// not a record you patch. There is deliberately no updateReceipt path — the
// only post-seal write is appending a correction note (see AuditReceipt.notes).
export type AuditReceipt = {
  readonly id: string; // human id, e.g. RCPT-2026-0184
  readonly hash: string; // tamper-evident hash of the sealed payload
  readonly caseId: string;
  readonly loanNumber: string;
  readonly reviewer: string;
  readonly signedAt: string;
  readonly policyVersionId: string;
  readonly outcome: "Cleared" | "Exceptions noted" | "Violations found";
  readonly findingIds: readonly string[];
  readonly evidenceIds: readonly string[];
  readonly sealed: boolean;
  readonly notes: readonly ReceiptNote[]; // append-only corrections after sealing
};

export type PolicyVersion = {
  id: string;
  label: string; // e.g. "Lending Policy v3.2"
  effectiveFrom: string;
  effectiveTo: string | null; // null = current
  dtiCap: number;
  ltvCap: number;
  minCreditScore: number;
};

export type Analytics = {
  totalCases: number;
  exceptionRate: number; // 0..1
  violationRate: number;
  unverifiableRate: number;
  missingEvidenceCount: number;
  slaAtRisk: number;
  approverDrift: { approver: string; exceptionRate: number; cases: number }[];
  branchRisk: { branch: string; highRiskShare: number }[];
  policyFailure: { policy: string; failureRate: number }[];
};
