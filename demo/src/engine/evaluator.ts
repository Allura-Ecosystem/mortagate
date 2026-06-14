import type {
  PolicyRule,
  PolicyEvaluationContext,
  RuleOutcome,
  EvaluationResult,
  Verdict,
  PreFlightResult,
} from './types';
import { STARTER_RULES } from './rules';

/**
 * Pure TypeScript port of PolicyRuleEvaluator (Apex).
 * Zero side effects. Zero network calls. Runs entirely in the browser.
 *
 * ADR-5: Three-layer engine with a pure kernel.
 * This IS the kernel — the same logic that runs on Salesforce.
 */

function evaluateOperator(
  factValue: number,
  operator: string,
  threshold: number | null,
  thresholdHigh: number | null
): boolean {
  if (threshold === null) return true;
  switch (operator) {
    case 'GT': return factValue > threshold;
    case 'GTE': return factValue >= threshold;
    case 'LT': return factValue < threshold;
    case 'LTE': return factValue <= threshold;
    case 'EQ': return factValue === threshold;
    case 'BETWEEN': return thresholdHigh !== null && factValue >= threshold && factValue <= thresholdHigh;
    default: return true;
  }
}

function deriveVerdict(outcomes: RuleOutcome[]): Verdict {
  // ADR-2: Worst-wins verdict precedence
  const hasHardDecline = outcomes.some(o => !o.passed && !o.indeterminate && o.severity === 'HARD_DECLINE');
  const hasSoftDecline = outcomes.some(o => !o.passed && !o.indeterminate && o.severity === 'SOFT_DECLINE');
  const hasWarning = outcomes.some(o => !o.passed && !o.indeterminate && o.severity === 'WARNING');

  if (hasHardDecline) return 'HARD_DECLINED';
  if (hasSoftDecline) return 'PENDING_REVIEW';
  if (hasWarning) return 'APPROVED_WITH_CONDITIONS';
  return 'APPROVED';
}

export function evaluate(context: PolicyEvaluationContext, rules?: PolicyRule[]): EvaluationResult {
  const activeRules = (rules ?? STARTER_RULES)
    .filter(r => r.isActive)
    .sort((a, b) => a.ruleCode.localeCompare(b.ruleCode)); // ADR-6: deterministic order

  const outcomes: RuleOutcome[] = activeRules.map(rule => {
    const factValue = context.facts[rule.factField];

    // ADR-3: Missing fact is INDETERMINATE, never a decline
    if (factValue === null || factValue === undefined) {
      return {
        ruleCode: rule.ruleCode,
        ruleLabel: rule.ruleLabel,
        severity: rule.severity,
        factField: rule.factField,
        factValue: null,
        operator: rule.operator,
        threshold: rule.thresholdValue,
        thresholdHigh: rule.thresholdHigh,
        passed: false,
        indeterminate: true,
        explanation: rule.ruleExplanation,
        regulatoryCitation: rule.regulatoryCitation,
      };
    }

    const numericValue = typeof factValue === 'number' ? factValue : parseFloat(String(factValue));
    const passed = evaluateOperator(numericValue, rule.operator, rule.thresholdValue, rule.thresholdHigh);

    return {
      ruleCode: rule.ruleCode,
      ruleLabel: rule.ruleLabel,
      severity: rule.severity,
      factField: rule.factField,
      factValue,
      operator: rule.operator,
      threshold: rule.thresholdValue,
      thresholdHigh: rule.thresholdHigh,
      passed,
      indeterminate: false,
      explanation: rule.ruleExplanation,
      regulatoryCitation: rule.regulatoryCitation,
    };
  });

  const verdict = deriveVerdict(outcomes);
  const failures = outcomes.filter(o => !o.passed && !o.indeterminate);
  const hardDeclines = failures.filter(o => o.severity === 'HARD_DECLINE');

  return {
    verdict,
    outcomes,
    totalRulesEvaluated: outcomes.length,
    hardDeclineCount: hardDeclines.length,
    softDeclineCount: failures.filter(o => o.severity === 'SOFT_DECLINE').length,
    warningCount: failures.filter(o => o.severity === 'WARNING').length,
    advisoryCount: failures.filter(o => o.severity === 'ADVISORY').length,
    firstDeclineReason: hardDeclines.length > 0 ? hardDeclines[0].explanation : null,
    evaluationTimestamp: new Date().toISOString(),
  };
}

/**
 * Pre-flight evaluator — same kernel, no record created (ADR-7).
 * Runs INCOME + COLLATERAL rules only for a soft band estimate.
 */
export function preFlightEvaluate(
  annualIncome: number,
  propertyValue: number,
  loanType: string = 'CONVENTIONAL'
): PreFlightResult {
  const assumedRate = 0.07;
  const termMonths = 360;
  const monthlyRate = assumedRate / 12;
  const maxDTI = 0.43;

  const maxMonthlyPayment = annualIncome / 12 * maxDTI;
  const maxLoan = maxMonthlyPayment * (1 - Math.pow(1 + monthlyRate, -termMonths)) / monthlyRate;

  const estimatedLTV = maxLoan / propertyValue;
  const estimatedDTI = (maxMonthlyPayment / (annualIncome / 12));

  const lowEstimate = Math.round(maxLoan * 0.85 / 1000) * 1000;
  const highEstimate = Math.round(maxLoan * 1.0 / 1000) * 1000;

  let eligibility: PreFlightResult['eligibility'];
  let guidance: string;

  if (estimatedDTI <= 0.36 && estimatedLTV <= 0.80) {
    eligibility = 'LIKELY_ELIGIBLE';
    guidance = 'Based on your income and property value, you\'re likely in range for conventional financing.';
  } else if (estimatedDTI <= 0.43) {
    eligibility = 'BORDERLINE';
    guidance = 'You\'re in a range worth exploring. Final approval depends on your full financial picture.';
  } else {
    eligibility = 'UNLIKELY';
    guidance = 'Based on these numbers alone, conventional financing may be challenging. Let\'s look at your options.';
  }

  return { eligibility, lowEstimate, highEstimate, estimatedDTI, estimatedLTV, guidance };
}
