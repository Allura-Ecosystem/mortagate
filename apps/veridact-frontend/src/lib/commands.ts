// Command layer — the ONE place a case is allowed to change.
//
// Brooks' rule of conceptual integrity: mutations do not happen scattered
// across click handlers. Every state change is a named command that asks the
// state machine (is this move legal?) and the role matrix (is this user
// allowed?) before it returns a result. The UI renders the result; it never
// decides policy on its own.

import type { CaseState, Role, ReplayCheck } from "./types";
import { TRANSITIONS, canTransition, transitionLabel, type TransitionEdge } from "./state-machine";
import { can, ALL_ROLES, type Action } from "./roles";

// nextState is optional: some commands (e.g. recording a finding) succeed
// without moving the case. A success that omits it leaves the state unchanged.
export type CommandResult =
  | { ok: true; nextState?: CaseState; message: string }
  | { ok: false; reason: string };

// The ONE place that says which permission each legal transition is gated on.
// Both the named commands and the Admin "who can do this" view read from here,
// so the enforced rule and the displayed rule can never disagree.
//
// Typed as a TOTAL Record<TransitionEdge, Action>: every edge in the
// TRANSITIONS graph MUST appear here (a missing one is a compile error) and no
// non-existent edge can sneak in. There is deliberately no runtime fallback —
// a silent default permission is exactly the kind of quiet drift a compliance
// system must not have. Add a transition to the graph and the compiler makes
// you state, right here, who is allowed to make it.
const TRANSITION_ACTION: Record<TransitionEdge, Action> = {
  "In Review>Evidence Needed": "edit_case",
  "In Review>Ready for Sign-off": "edit_case",
  "Evidence Needed>In Review": "edit_case",
  "Ready for Sign-off>Closed": "sign_off",
  "Ready for Sign-off>In Review": "edit_case",
  "Closed>In Review": "reassign_case",
};

// Only ever called for a legal edge — move(), canIssueCommand() and
// describeTransitions() all gate on canTransition()/the TRANSITIONS graph
// first, so the key is guaranteed present. No `?? fallback`: an unmapped edge
// would be a type error above, not a silent guess at sign-off time.
export function actionForTransition(from: CaseState, to: CaseState): Action {
  return TRANSITION_ACTION[`${from}>${to}` as TransitionEdge];
}

// Dry-run check: may this role make this exact move? Same double-lock a real
// command runs (legal transition AND permission) but with no side effects —
// so the UI can enable/disable a control without simulating a command.
export function canIssueCommand(from: CaseState, to: CaseState, role: Role): boolean {
  return canTransition(from, to, role).ok && can(role, actionForTransition(from, to));
}

// A move requires BOTH a legal transition and the right permission.
function move(
  from: CaseState,
  to: CaseState,
  role: Role,
  okMessage: string,
): CommandResult {
  const t = canTransition(from, to, role);
  if (!t.ok) return { ok: false, reason: t.reason ?? `Cannot move to ${to}.` };
  if (!can(role, actionForTransition(from, to))) {
    return { ok: false, reason: `Your role (${role}) cannot ${transitionLabel(from, to).toLowerCase()}.` };
  }
  return { ok: true, nextState: to, message: okMessage };
}

export function requestEvidence(from: CaseState, role: Role): CommandResult {
  return move(from, "Evidence Needed", role,
    "Evidence requested. Case moved to “Evidence Needed”.");
}

export function markReadyForSignoff(from: CaseState, role: Role): CommandResult {
  return move(from, "Ready for Sign-off", role,
    "Marked ready for sign-off. A reviewer can now seal the receipt.");
}

export function sealCase(from: CaseState, role: Role): CommandResult {
  return move(from, "Closed", role,
    "Case sealed. An immutable receipt has been created.");
}

export function reopenCase(from: CaseState, role: Role): CommandResult {
  return move(from, "In Review", role,
    "Case reopened for review.");
}

export function createFinding(role: Role): CommandResult {
  if (!can(role, "create_finding")) {
    return { ok: false, reason: `Your role (${role}) cannot record findings.` };
  }
  // Recording a finding does not itself change case state — no nextState.
  return { ok: true, message: "Finding recorded." };
}

// The ONE place that names what stops a case from being sealed cleanly. A
// "Violation" has no valid approval and an "Unverifiable" check can't be
// confirmed — neither belongs in a sealed receipt until it's resolved or a
// finding is recorded. The sign-off button, its tooltip, and any future
// server-side guard all read this, so the rule can't be stated two ways.
export function signoffBlockers(checks: ReplayCheck[]): string[] {
  const out: string[] = [];
  const violations = checks.filter((c) => c.status === "Violation").length;
  const unverifiable = checks.filter((c) => c.status === "Unverifiable").length;
  if (violations) out.push(`${violations} violation${violations > 1 ? "s" : ""}`);
  if (unverifiable)
    out.push(`${unverifiable} unverifiable check${unverifiable > 1 ? "s" : ""}`);
  return out;
}

// One canonical description of the whole state flow, computed from the
// transition graph + the role matrix. The Admin page renders THIS instead of
// keeping its own copy of the rules, so the displayed flow cannot drift from
// what the app enforces.
export type TransitionInfo = {
  from: CaseState;
  to: CaseState;
  label: string;
  roles: Role[];
};

export function describeTransitions(): TransitionInfo[] {
  const out: TransitionInfo[] = [];
  for (const from of Object.keys(TRANSITIONS) as CaseState[]) {
    for (const to of TRANSITIONS[from]) {
      const roles = ALL_ROLES.filter((r) => canIssueCommand(from, to, r));
      out.push({ from, to, label: transitionLabel(from, to), roles });
    }
  }
  return out;
}
