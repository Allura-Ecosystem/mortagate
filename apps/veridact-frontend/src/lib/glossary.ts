// Plain-language glosses for the jargon a non-expert hits in this app.
// Used by the <Term> component so every acronym explains itself on hover/focus.

export const GLOSSARY: Record<string, string> = {
  LTV: "Loan-to-value: how much was borrowed compared to the home's value. 90% LTV means the loan is 90% of the home's price.",
  DTI: "Debt-to-income: the share of the borrower's monthly income that goes to debt payments. Lower is safer.",
  QC: "Quality control: a second check that the loan was approved by the rules.",
  Replay:
    "Re-running each lending rule against the policy that was in force on the day the loan was approved — not today's rules.",
  Exception:
    "A rule was bent, but a manager signed off on it at the time. Allowed only if the policy then permitted it.",
  Violation:
    "A rule was broken with no valid approval. This is the main thing the audit exists to catch.",
  Unverifiable:
    "We can't confirm the rule was met because the evidence is missing, expired, or unclear.",
  Pass: "The rule was met. Nothing to flag.",
  Exemption: "Permission to skip or bend a rule for this loan.",
  SLA: "Service-level agreement: the deadline by which this audit should be finished.",
  Sampling: "How this loan was picked for audit — at random, by risk, or on purpose.",
  triage: "Sorting the cases so the riskiest or most overdue ones get looked at first.",
  "sign-off": "A reviewer's formal approval that the audit is complete. It seals the receipt so it can't be changed.",
  seal: "Locking the finished audit into a receipt so the record can't be quietly edited later. Anything learned afterward is added as a dated note, not an edit.",
  finding: "A problem the audit found — a broken rule, a bent rule, or evidence we couldn't confirm. Each finding is written up so a reviewer can act on it.",
  hash: "A short fingerprint calculated from the sealed record. If even one character of the record changed, the fingerprint would no longer match — that's how tampering is caught.",
  Linked: "The document is on file and matches the loan — nothing to flag.",
  Missing: "The document we expected isn't here, so the rule it backs can't be confirmed.",
  Mismatch: "The document is here, but a number in it doesn't match what the loan used.",
  Expired: "The document is too old to count — e.g. comps more than 180 days before approval.",
  Contradictory: "The document conflicts with itself or with the loan — e.g. it cites a rule that didn't exist yet.",
};

export function glossFor(term: string): string | undefined {
  return GLOSSARY[term];
}
