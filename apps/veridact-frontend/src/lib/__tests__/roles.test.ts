import { describe, it, expect } from "vitest";
import { can } from "../roles";

describe("role permission matrix", () => {
  it("an Auditor can create findings and edit a case, but cannot sign off", () => {
    expect(can("Auditor", "create_finding")).toBe(true);
    expect(can("Auditor", "edit_case")).toBe(true);
    expect(can("Auditor", "sign_off")).toBe(false);
  });

  it("a Reviewer can sign off", () => {
    expect(can("Reviewer", "sign_off")).toBe(true);
  });

  it("only an Admin can manage policy", () => {
    expect(can("Admin", "manage_policy")).toBe(true);
    expect(can("Manager", "manage_policy")).toBe(false);
    expect(can("Reviewer", "manage_policy")).toBe(false);
  });

  it("a Compliance Viewer can only export receipts", () => {
    expect(can("Compliance Viewer", "export_receipt")).toBe(true);
    expect(can("Compliance Viewer", "create_finding")).toBe(false);
    expect(can("Compliance Viewer", "sign_off")).toBe(false);
  });
});
