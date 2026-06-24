import { describe, it, expect } from "vitest";
import { canTransition, nextStates, transitionLabel } from "../state-machine";

describe("case state machine", () => {
  it("allows the designed forward moves from In Review", () => {
    expect(canTransition("In Review", "Evidence Needed", "Auditor").ok).toBe(true);
    expect(canTransition("In Review", "Ready for Sign-off", "Auditor").ok).toBe(true);
  });

  it("rejects illegal jumps", () => {
    // Cannot leap straight from In Review to Closed.
    const r = canTransition("In Review", "Closed", "Admin");
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/No path/);
  });

  it("only a Reviewer/Manager/Admin can seal (close) a case", () => {
    expect(canTransition("Ready for Sign-off", "Closed", "Auditor").ok).toBe(false);
    expect(canTransition("Ready for Sign-off", "Closed", "Reviewer").ok).toBe(true);
    expect(canTransition("Ready for Sign-off", "Closed", "Manager").ok).toBe(true);
  });

  it("reopening a Closed case is privileged (Manager/Admin only)", () => {
    expect(canTransition("Closed", "In Review", "Reviewer").ok).toBe(false);
    expect(canTransition("Closed", "In Review", "Manager").ok).toBe(true);
    expect(canTransition("Closed", "In Review", "Admin").ok).toBe(true);
  });

  it("exposes the legal next states", () => {
    expect(nextStates("In Review")).toEqual(["Evidence Needed", "Ready for Sign-off"]);
    expect(nextStates("Closed")).toEqual(["In Review"]);
  });

  it("labels moves in plain language", () => {
    expect(transitionLabel("Ready for Sign-off", "Closed")).toBe("Seal the receipt");
    expect(transitionLabel("In Review", "Evidence Needed")).toBe("Request evidence");
  });
});
