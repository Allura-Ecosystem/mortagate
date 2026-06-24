export type Operator = 'GT' | 'GTE' | 'LT' | 'LTE' | 'EQ' | 'BETWEEN' | 'IN_LIST' | 'NOT_IN_LIST';
export type Severity = 'HARD_DECLINE' | 'SOFT_DECLINE' | 'WARNING' | 'ADVISORY';
export type Verdict = 'APPROVED' | 'APPROVED_WITH_CONDITIONS' | 'PENDING_REVIEW' | 'HARD_DECLINED';
export type RuleCategory = 'INCOME' | 'CREDIT' | 'COLLATERAL' | 'COMPLIANCE' | 'FRAUD' | 'RESIDENCY';

export interface PolicyRule {
  ruleCode: string;
  ruleLabel: string;
  category: RuleCategory;
  operator: Operator;
  thresholdValue: number | null;
  thresholdHigh: number | null;
  allowedValues: string[] | null;
  factField: string;
  severity: Severity;
  ruleExplanation: string;
  regulatoryCitation: string | null;
  versionNumber: number;
  isActive: boolean;
}

export interface PolicyEvaluationContext {
  applicationId: string;
  facts: Record<string, number | string | null>;
}

export interface RuleOutcome {
  ruleCode: string;
  ruleLabel: string;
  severity: Severity;
  factField: string;
  factValue: number | string | null;
  operator: Operator;
  threshold: number | null;
  thresholdHigh: number | null;
  passed: boolean;
  indeterminate: boolean;
  explanation: string;
  regulatoryCitation: string | null;
}

export interface EvaluationResult {
  verdict: Verdict;
  outcomes: RuleOutcome[];
  totalRulesEvaluated: number;
  hardDeclineCount: number;
  softDeclineCount: number;
  warningCount: number;
  advisoryCount: number;
  firstDeclineReason: string | null;
  evaluationTimestamp: string;
}

export interface Persona {
  id: string;
  name: string;
  fico: number;
  dti: number;
  annualIncome: number;
  propertyValue: number;
  employmentTenureMonths: number;
  addressTenureMonths: number;
  ltv: number;
  loanPurpose: 'PURCHASE' | 'REFINANCE';
  expectedVerdict: Verdict;
  story: string;
}

export interface PreFlightResult {
  eligibility: 'LIKELY_ELIGIBLE' | 'BORDERLINE' | 'UNLIKELY';
  lowEstimate: number;
  highEstimate: number;
  estimatedDTI: number;
  estimatedLTV: number;
  guidance: string;
}
