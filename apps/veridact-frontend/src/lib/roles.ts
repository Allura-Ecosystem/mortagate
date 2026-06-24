// Role permissions (mock). Drives which actions render as enabled.

import type { Role } from "./types";

export type Action =
  | "create_finding"
  | "sign_off"
  | "reassign_case"
  | "manage_policy"
  | "export_receipt"
  | "edit_case";

const MATRIX: Record<Role, Action[]> = {
  Auditor: ["create_finding", "edit_case", "export_receipt"],
  Reviewer: ["create_finding", "sign_off", "export_receipt", "edit_case"],
  Manager: ["create_finding", "sign_off", "reassign_case", "export_receipt", "edit_case"],
  Admin: ["create_finding", "sign_off", "reassign_case", "manage_policy", "export_receipt", "edit_case"],
  "Compliance Viewer": ["export_receipt"],
};

export function can(role: Role, action: Action): boolean {
  return MATRIX[role]?.includes(action) ?? false;
}

// Every role the matrix knows about — the single list other modules iterate
// (e.g. to derive "who can do this move?") so no second role list can drift.
export const ALL_ROLES = Object.keys(MATRIX) as Role[];

// Plain-language label for each permission. This is the ONLY place an action
// is described in words, so the Admin "who can do what" view is computed from
// MATRIX rather than hand-typed prose that could silently disagree with can().
export const ACTION_LABEL: Record<Action, string> = {
  edit_case: "open and work cases (request evidence, move them along)",
  create_finding: "record findings",
  sign_off: "seal cases (sign-off)",
  reassign_case: "reassign cases and reopen closed ones",
  manage_policy: "edit policy versions",
  export_receipt: "export receipts",
};

// Stable, human-friendly order so the derived capability list reads the same
// way every time regardless of how MATRIX happens to be authored.
const ACTION_ORDER: Action[] = [
  "edit_case",
  "create_finding",
  "sign_off",
  "reassign_case",
  "manage_policy",
  "export_receipt",
];

// What a role can do, in plain language, derived straight from MATRIX via can().
// Add an Action to a role in MATRIX and this list updates itself — no second
// description to keep in sync.
export function describeRole(role: Role): string[] {
  return ACTION_ORDER.filter((a) => can(role, a)).map((a) => ACTION_LABEL[a]);
}

// The auditor signed in for this demo. Real auth comes in a later milestone.
export const CURRENT_ROLE: Role = "Auditor";
export const CURRENT_USER = "S. Asheed";
