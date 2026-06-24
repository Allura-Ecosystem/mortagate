import type { Persona } from './types';

export const PERSONAS: Persona[] = [
  {
    id: 'karim',
    name: 'Karim Hassan',
    fico: 727,
    dti: 0.331,
    annualIncome: 97803,
    propertyValue: 425000,
    employmentTenureMonths: 126,
    addressTenureMonths: 48,
    ltv: 0.80,
    loanPurpose: 'PURCHASE',
    expectedVerdict: 'APPROVED',
    story: 'Clean approval. All rules pass. The system works as expected.',
  },
  {
    id: 'maria',
    name: 'Maria Santos',
    fico: 704,
    dti: 0.086,
    annualIncome: 55961,
    propertyValue: 280000,
    employmentTenureMonths: 14,
    addressTenureMonths: 24,
    ltv: 0.80,
    loanPurpose: 'PURCHASE',
    expectedVerdict: 'APPROVED_WITH_CONDITIONS',
    story: 'Short employment history (14 months) triggers a WARNING — not a decline, just a flag for additional verification.',
  },
  {
    id: 'james',
    name: "James O'Brien",
    fico: 688,
    dti: 0.517,
    annualIncome: 80393,
    propertyValue: 350000,
    employmentTenureMonths: 14,
    addressTenureMonths: 18,
    ltv: 0.80,
    loanPurpose: 'PURCHASE',
    expectedVerdict: 'HARD_DECLINED',
    story: 'DTI of 51.7% exceeds the 43% CFPB threshold. The adverse action notice cites the specific regulation.',
  },
  {
    id: 'sabir',
    name: 'Sabir Asheed Sr.',
    fico: 698,
    dti: 0.431,
    annualIncome: 80023,
    propertyValue: 380000,
    employmentTenureMonths: 241,
    addressTenureMonths: 120,
    ltv: 0.80,
    loanPurpose: 'PURCHASE',
    expectedVerdict: 'HARD_DECLINED',
    story: 'The audit gap. Dad\'s internal guideline (45%) would approve this borrower. The system\'s 43% CFPB threshold catches the regulatory risk. This is the drift that costs banks millions in fines.',
  },
  {
    id: 'test',
    name: 'Test Borrower',
    fico: 570,
    dti: 0.035,
    annualIncome: 32015,
    propertyValue: 150000,
    employmentTenureMonths: 161,
    addressTenureMonths: 72,
    ltv: 0.80,
    loanPurpose: 'PURCHASE',
    expectedVerdict: 'HARD_DECLINED',
    story: 'FICO score of 570 is below the 620 minimum. Low DTI and long employment don\'t matter — credit score is a hard gate.',
  },
];

export function getPersona(id: string): Persona | undefined {
  return PERSONAS.find(p => p.id === id);
}

export function personaToFacts(persona: Persona): Record<string, number | string | null> {
  return {
    DTI_Ratio__c: persona.dti,
    FICO_Score__c: persona.fico,
    LTV_Ratio__c: persona.ltv,
    Annual_Income__c: persona.annualIncome,
    Employment_Tenure_Months__c: persona.employmentTenureMonths,
    Address_Tenure_Months__c: persona.addressTenureMonths,
  };
}
