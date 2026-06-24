import { notFound } from "next/navigation";
import {
  getAuditCase,
  getReplayChecks,
  getEvidence,
  getFindings,
  getPolicyVersion,
} from "@/lib/api";
import { CaseReviewClient } from "@/components/CaseReviewClient";

export default async function CaseReviewPage({
  params,
}: {
  params: Promise<{ caseId: string }>;
}) {
  const { caseId } = await params;
  const auditCase = await getAuditCase(caseId);
  if (!auditCase) notFound();

  const [checks, evidence, findings, policy] = await Promise.all([
    getReplayChecks(auditCase.id),
    getEvidence(auditCase.id),
    getFindings(auditCase.id),
    getPolicyVersion(auditCase.policyVersionId),
  ]);

  return (
    <CaseReviewClient
      auditCase={auditCase}
      checks={checks}
      evidence={evidence}
      findings={findings}
      policyLabel={policy?.label ?? auditCase.policyVersionId}
    />
  );
}
