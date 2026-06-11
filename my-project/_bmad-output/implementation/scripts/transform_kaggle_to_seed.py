#!/usr/bin/env python3
"""Transform Kaggle loan data into Salesforce seed JSON for Mortgate demo.

Reads: data/kaggle/Loan_approval_data_2025.csv
Writes: data/demo/Loan_Application__c.json
        data/demo/Extracted_Facts__c.json
        data/demo/demo-scenarios.json

Usage: python3 scripts/transform_kaggle_to_seed.py
"""

import csv
import json
import os
import random
from datetime import datetime, timedelta

KAGGLE_CSV = "data/kaggle/Loan_approval_data_2025.csv"
OUTPUT_DIR = "data/demo"

# Demo scenario selection criteria
SCENARIOS = {
    "clean_approval": {
        "label": "Clean Approval — Karim Hassan",
        "narrative": "Strong borrower. All rules pass. Verdict: APPROVED.",
        "filter": lambda r: (
            int(r["credit_score"]) >= 720
            and float(r["debt_to_income_ratio"]) <= 0.35
            and float(r["years_employed"]) >= 5
            and float(r["annual_income"]) >= 80000
        ),
    },
    "conditional_short_employment": {
        "label": "Conditional — Maria Santos",
        "narrative": "Good credit, low DTI, but under 2 years at current employer. WARNING fires on EMPLOYMENT_TENURE. Verdict: APPROVED_WITH_CONDITIONS.",
        "filter": lambda r: (
            int(r["credit_score"]) >= 680
            and float(r["debt_to_income_ratio"]) <= 0.38
            and float(r["years_employed"]) < 2
            and float(r["years_employed"]) >= 0.5
            and float(r["annual_income"]) >= 50000
        ),
    },
    "hard_decline_dti": {
        "label": "Hard Decline (DTI) — James O'Brien",
        "narrative": "DTI at 48% exceeds 43% threshold. HARD_DECLINE fires. Adverse action notice generated with specific reason.",
        "filter": lambda r: (
            int(r["credit_score"]) >= 650
            and float(r["debt_to_income_ratio"]) >= 0.47
            and float(r["debt_to_income_ratio"]) <= 0.55
            and float(r["annual_income"]) >= 60000
        ),
    },
    "integration_boundary": {
        "label": "Integration Boundary — Sabir Asheed Sr.",
        "narrative": "DTI at 44% — dad's 45% guideline would approve, but system's 43% threshold catches it. This is the integration boundary made visible.",
        "filter": lambda r: (
            int(r["credit_score"]) >= 680
            and float(r["debt_to_income_ratio"]) > 0.43
            and float(r["debt_to_income_ratio"]) <= 0.45
            and float(r["years_employed"]) >= 3
            and float(r["annual_income"]) >= 50000
        ),
    },
    "fico_decline": {
        "label": "FICO Decline — Test Borrower",
        "narrative": "Credit score 580, below 620 minimum. HARD_DECLINE fires on FICO_MIN. All other facts are strong.",
        "filter": lambda r: (
            int(r["credit_score"]) >= 560
            and int(r["credit_score"]) < 620
            and float(r["debt_to_income_ratio"]) <= 0.35
            and float(r["years_employed"]) >= 5
        ),
    },
}

# Persona names for demo scenarios (overrides customer_id)
PERSONA_NAMES = {
    "clean_approval": "Karim Hassan",
    "conditional_short_employment": "Maria Santos",
    "hard_decline_dti": "James O'Brien",
    "integration_boundary": "Sabir Asheed Sr.",
    "fico_decline": "Test Borrower",
}


def read_kaggle_csv():
    with open(KAGGLE_CSV, newline="") as f:
        return list(csv.DictReader(f))


def select_scenarios(rows):
    """Select one representative row per scenario."""
    selected = {}
    for key, spec in SCENARIOS.items():
        candidates = [r for r in rows if spec["filter"](r)]
        if not candidates:
            raise ValueError(f"No candidates found for scenario: {key}")
        # Pick the first match (deterministic)
        selected[key] = candidates[0]
    return selected


def select_bulk(rows, exclude_ids, count=200):
    """Select 200 rows for bulk safety testing, excluding demo rows."""
    pool = [r for r in rows if r["customer_id"] not in exclude_ids]
    random.seed(42)  # Deterministic for reproducibility
    return random.sample(pool, min(count, len(pool)))


def synthesize_property_value(annual_income, dti):
    """Derive a plausible property value from income and DTI."""
    # Assume mortgage payment is ~30% of the DTI burden
    # and a 30-year term at ~7% rate
    monthly_income = annual_income / 12
    estimated_payment = monthly_income * dti * 0.6
    # Rough price from payment (P&I at 7%, 360 months, factor ~6.65)
    if estimated_payment > 0:
        loan_amount = estimated_payment * 150  # rough multiplier
        property_value = loan_amount / 0.80  # assume 80% LTV
    else:
        property_value = annual_income * 4  # fallback
    return round(max(property_value, 100000), 2)


def synthesize_address_tenure(years_employed):
    """Derive address tenure from employment. People often move for jobs."""
    # Address tenure is typically >= employment tenure
    base = years_employed * 12
    return max(int(base + random.randint(0, 24)), 6)


def to_loan_application(row, ref_id, persona_name=None):
    """Convert a Kaggle row to a Loan_Application__c record."""
    income = float(row["annual_income"])
    dti = float(row["debt_to_income_ratio"])
    prop_value = synthesize_property_value(income, dti)
    requested = round(prop_value * 0.80, 2)  # 80% LTV default

    return {
        "attributes": {
            "type": "Loan_Application__c",
            "referenceId": ref_id,
        },
        "Status__c": "SUBMITTED",
        "Purpose__c": "PURCHASE",
        "Property_Value__c": prop_value,
        "Requested_Amount__c": requested,
        "Annual_Income__c": income,
        "Current_Stage__c": "REVIEW",
        "Loan_Type__c": "CONVENTIONAL",
    }


def to_extracted_facts(row, ref_id, app_ref_id):
    """Convert a Kaggle row to an Extracted_Facts__c record."""
    income = float(row["annual_income"])
    emp_years = float(row["years_employed"])
    dti = float(row["debt_to_income_ratio"])
    fico = int(row["credit_score"])
    prop_value = synthesize_property_value(income, dti)
    requested = prop_value * 0.80
    ltv = requested / prop_value if prop_value > 0 else 0

    random.seed(hash(row["customer_id"]))  # Deterministic per customer
    addr_tenure = synthesize_address_tenure(emp_years)

    return {
        "attributes": {
            "type": "Extracted_Facts__c",
            "referenceId": ref_id,
        },
        "Application__c": f"@{app_ref_id}",
        "Fact_Type__c": "CREDIT",
        "Annual_Income__c": income,
        "Monthly_Income__c": round(income / 12, 2),
        "DTI_Ratio__c": round(dti * 100, 4),  # Percent field: 0.43 -> 43.0000
        "FICO_Score__c": fico,
        "LTV_Ratio__c": round(ltv * 100, 4),  # Percent field
        "Employment_Months__c": int(emp_years * 12),
        "Address_Tenure_Months__c": addr_tenure,
        "Asset_Value__c": float(row["savings_assets"]),
        "Extracted_Date__c": datetime.now().strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "Verified__c": True,
    }


def build_scenario_metadata(scenarios_selected):
    """Build demo-scenarios.json with narrative and expected outcomes."""
    meta = []
    for key, row in scenarios_selected.items():
        spec = SCENARIOS[key]
        meta.append({
            "scenario_key": key,
            "persona": PERSONA_NAMES[key],
            "kaggle_customer_id": row["customer_id"],
            "label": spec["label"],
            "narrative": spec["narrative"],
            "facts": {
                "credit_score": int(row["credit_score"]),
                "dti_ratio": float(row["debt_to_income_ratio"]),
                "annual_income": float(row["annual_income"]),
                "years_employed": float(row["years_employed"]),
            },
            "app_ref": f"app_{key}",
            "facts_ref": f"facts_{key}",
        })
    return meta


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    rows = read_kaggle_csv()
    print(f"Loaded {len(rows)} Kaggle records")

    # Select demo scenarios
    scenarios = select_scenarios(rows)
    print(f"Selected {len(scenarios)} demo scenarios:")
    for key, row in scenarios.items():
        print(f"  {key}: {row['customer_id']} FICO={row['credit_score']} DTI={row['debt_to_income_ratio']} income={row['annual_income']}")

    # Select bulk records
    exclude = {row["customer_id"] for row in scenarios.values()}
    bulk = select_bulk(rows, exclude, 200)
    print(f"Selected {len(bulk)} bulk records")

    # Build Salesforce records
    apps = []
    facts = []

    # Demo scenarios first
    for key, row in scenarios.items():
        app_ref = f"app_{key}"
        facts_ref = f"facts_{key}"
        apps.append(to_loan_application(row, app_ref, PERSONA_NAMES[key]))
        facts.append(to_extracted_facts(row, facts_ref, app_ref))

    # Bulk records
    for i, row in enumerate(bulk):
        app_ref = f"app_bulk_{i:03d}"
        facts_ref = f"facts_bulk_{i:03d}"
        apps.append(to_loan_application(row, app_ref))
        facts.append(to_extracted_facts(row, facts_ref, app_ref))

    # Write output
    with open(os.path.join(OUTPUT_DIR, "Loan_Application__c.json"), "w") as f:
        json.dump({"records": apps}, f, indent=2)
    print(f"Wrote {len(apps)} Loan_Application__c records")

    with open(os.path.join(OUTPUT_DIR, "Extracted_Facts__c.json"), "w") as f:
        json.dump({"records": facts}, f, indent=2)
    print(f"Wrote {len(facts)} Extracted_Facts__c records")

    # Write scenario metadata
    meta = build_scenario_metadata(scenarios)
    with open(os.path.join(OUTPUT_DIR, "demo-scenarios.json"), "w") as f:
        json.dump(meta, f, indent=2)
    print(f"Wrote {len(meta)} demo scenario definitions")

    print(f"\nDone. Files in {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
