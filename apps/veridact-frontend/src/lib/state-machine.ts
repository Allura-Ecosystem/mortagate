// Explicit case state machine. No random status jumping —
// banks do not like vibes-based compliance.

import type { CaseState, Role } from "./types";

export const TRANSITIONS = {
  "In Review": ["Evidence Needed", "Ready for Sign-off"],
  "Evidence Needed": ["In Review"],
  "Ready for Sign-off": ["Closed", "In Review"],
  // Reopening a closed case is a privileged move (see canTransition).
  Closed: ["In Review"],
} as const satisfies Record<CaseState, readonly CaseState[]>;

// Every legal "from>to" edge, derived from the graph above at the TYPE level.
// Because TRANSITIONS is `as const`, the exact edge set is known to the
// compiler — so anything keyed by TransitionEdge (e.g. the permission map in
// commands.ts) must cover every edge and no phantom ones. Add an edge to the
// graph and the compiler forces you to assign it a permission. No silent drift.
export type TransitionEdge = {
  [F in keyof typeof TRANSITIONS]: `${F & string}>${(typeof TRANSITIONS)[F][number]}`;
}[keyof typeof TRANSITIONS];

// Reopening a Closed case requires Manager/Admin.
export function canTransition(
  from: CaseState,
  to: CaseState,
  role: Role,
): { ok: boolean; reason?: string } {
  if (!(TRANSITIONS[from] as readonly CaseState[])?.includes(to)) {
    return { ok: false, reason: `No path from "${from}" to "${to}".` };
  }
  if (from === "Closed" && to === "In Review" && !(role === "Manager" || role === "Admin")) {
    return { ok: false, reason: "Only a Manager or Admin can reopen a closed case." };
  }
  if (to === "Closed" && !(role === "Reviewer" || role === "Manager" || role === "Admin")) {
    return { ok: false, reason: "Only a Reviewer can sign off and close a case." };
  }
  return { ok: true };
}

export function nextStates(from: CaseState): readonly CaseState[] {
  return TRANSITIONS[from] ?? [];
}

// Plain-language name for a move, so the UI can label buttons and explain
// permission errors without re-inventing wording in each component.
const TRANSITION_LABEL: Partial<Record<`${CaseState}>${CaseState}`, string>> = {
  "In Review>Evidence Needed": "Request evidence",
  "In Review>Ready for Sign-off": "Mark ready for sign-off",
  "Evidence Needed>In Review": "Resume review",
  "Ready for Sign-off>Closed": "Seal the receipt",
  "Ready for Sign-off>In Review": "Reopen for review",
  "Closed>In Review": "Reopen the closed case",
};

export function transitionLabel(from: CaseState, to: CaseState): string {
  return TRANSITION_LABEL[`${from}>${to}`] ?? `Move to ${to}`;
}
