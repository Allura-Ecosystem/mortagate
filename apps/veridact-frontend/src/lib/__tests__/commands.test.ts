import { describe, it, expect } from "vitest";
import {
  requestEvidence,
  markReadyForSignoff,
  sealCase,
  reopenCase,
  createFinding,
  canIssueCommand,
  describeTransitions,
  signoffBlockers,
} from "../commands";
import type { ReplayCheck } from "../types";

function check(status: ReplayCheck["status"]): ReplayCheck {
  return { id: status, ruleId: "dti-threshold", ruleName: "r", detail: "d", status } as ReplayCheck;
}

describe("command layer (state machine + roles together)", () => {
  it("requestEvidence moves In Review -> Evidence Needed for an Auditor", () => {
    const r = requestEvidence("In Review", "Auditor");
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.nextState).toBe("Evidence Needed");
  });

  it("markReadyForSignoff works from In Review", () => {
    expect(markReadyForSignoff("In Review", "Auditor").ok).toBe(true);
    // No legal path from Evidence Needed straight to Ready for Sign-off.
    expect(markReadyForSignoff("Evidence Needed", "Auditor").ok).toBe(false);
  });

  it("sealCase requires sign-off permission", () => {
    expect(sealCase("Ready for Sign-off", "Auditor").ok).toBe(false);
    expect(sealCase("Ready for Sign-off", "Reviewer").ok).toBe(true);
  });

  it("reopenCase is blocked for an Auditor and allowed for a Manager", () => {
    expect(reopenCase("Closed", "Auditor").ok).toBe(false);
    expect(reopenCase("Closed", "Manager").ok).toBe(true);
  });

  it("createFinding is gated by permission and does not move the case", () => {
    const r = createFinding("Auditor");
    expect(r.ok).toBe(true);
    // Recording a finding succeeds without a state change.
    if (r.ok) expect(r.nextState).toBeUndefined();
    expect(createFinding("Compliance Viewer").ok).toBe(false);
  });

  it("canIssueCommand mirrors the real command guard (no side effects)", () => {
    expect(canIssueCommand("In Review", "Ready for Sign-off", "Auditor")).toBe(true);
    expect(canIssueCommand("Ready for Sign-off", "Closed", "Auditor")).toBe(false);
    expect(canIssueCommand("Ready for Sign-off", "Closed", "Reviewer")).toBe(true);
    expect(canIssueCommand("Closed", "In Review", "Auditor")).toBe(false);
    expect(canIssueCommand("Closed", "In Review", "Manager")).toBe(true);
  });

  it("describeTransitions derives the flow from the canonical graph + matrix", () => {
    const flow = describeTransitions();
    // Covers every edge in the transition graph (incl. Ready→In Review).
    expect(flow).toHaveLength(6);
    const seal = flow.find((t) => t.from === "Ready for Sign-off" && t.to === "Closed");
    expect(seal?.roles).toEqual(["Reviewer", "Manager", "Admin"]);
    const reopen = flow.find((t) => t.from === "Closed" && t.to === "In Review");
    expect(reopen?.roles).toEqual(["Manager", "Admin"]);
    // Compliance Viewer can never move a case.
    expect(flow.every((t) => !t.roles.includes("Compliance Viewer"))).toBe(true);
  });

  it("signoffBlockers names violations and unverifiable checks, ignores pass/exception", () => {
    // A clean case (only Pass / Exception) has nothing blocking a seal.
    expect(signoffBlockers([check("Pass"), check("Exception")])).toEqual([]);
    // Violations and unverifiable checks are surfaced, pluralized, in order.
    expect(
      signoffBlockers([check("Violation"), check("Violation"), check("Unverifiable")]),
    ).toEqual(["2 violations", "1 unverifiable check"]);
    expect(signoffBlockers([check("Violation")])).toEqual(["1 violation"]);
  });
});
