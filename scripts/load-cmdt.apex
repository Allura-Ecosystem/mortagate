/**
 * load-cmdt.apex — Post-deploy loader for Veridact CustomMetadata config records.
 *
 * WHY THIS EXISTS (ADR-19 / R-9): on the Agentforce-trial org family, deploying
 * these 2 CustomMetadata RECORDS via `sf project deploy start` throws a server-side
 * UNKNOWN_EXCEPTION (Salesforce support ErrorId) even though the records are valid
 * and the __mdt TYPES deploy fine. The Apex Metadata API is a different code path
 * and places them cleanly. Exclude force-app/main/default/customMetadata/ from the
 * CLI deploy and run this after deploy instead:
 *
 *   sf apex run --file scripts/load-cmdt.apex --target-org <alias>
 *
 * Verify:  SELECT DeveloperName FROM PreFlight_Assumption__mdt
 *          SELECT DeveloperName FROM Adverse_Action_Config__mdt
 */
Metadata.DeployContainer container = new Metadata.DeployContainer();

// ── PreFlight_Assumption.Default (Screen 3 pre-check illustrative assumptions; R-5) ──
Metadata.CustomMetadata pf = new Metadata.CustomMetadata();
pf.fullName = 'PreFlight_Assumption.Default';
pf.label = 'Default';
Metadata.CustomMetadataValue pfa = new Metadata.CustomMetadataValue();
pfa.field = 'Annual_Rate__c';   pfa.value = 0.07;  pf.values.add(pfa);
Metadata.CustomMetadataValue pfb = new Metadata.CustomMetadataValue();
pfb.field = 'Term_Months__c';   pfb.value = 360;   pf.values.add(pfb);
Metadata.CustomMetadataValue pfc = new Metadata.CustomMetadataValue();
pfc.field = 'Debt_Headroom__c'; pfc.value = 0.05;  pf.values.add(pfc);
Metadata.CustomMetadataValue pfd = new Metadata.CustomMetadataValue();
pfd.field = 'Band_Width__c';    pfd.value = 0.08;  pf.values.add(pfd);
container.addMetadata(pf);

// ── Adverse_Action_Config.Default (ECOA/Reg B notice config-as-data; ADR-10, R-7) ──
Metadata.CustomMetadata aa = new Metadata.CustomMetadata();
aa.fullName = 'Adverse_Action_Config.Default';
aa.label = 'Default';
Metadata.CustomMetadataValue a1 = new Metadata.CustomMetadataValue();
a1.field = 'Creditor_Name__c'; a1.value = 'Veridact Lending'; aa.values.add(a1);
Metadata.CustomMetadataValue a2 = new Metadata.CustomMetadataValue();
a2.field = 'Creditor_Address__c'; a2.value = 'Veridact Lending, 1 Market Street, Suite 400, San Francisco, CA 94105'; aa.values.add(a2);
Metadata.CustomMetadataValue a3 = new Metadata.CustomMetadataValue();
a3.field = 'Oversight_Agency_Name__c'; a3.value = 'Consumer Financial Protection Bureau'; aa.values.add(a3);
Metadata.CustomMetadataValue a4 = new Metadata.CustomMetadataValue();
a4.field = 'Oversight_Agency_Address__c'; a4.value = 'Consumer Financial Protection Bureau, 1700 G Street NW, Washington, DC 20006'; aa.values.add(a4);
Metadata.CustomMetadataValue a5 = new Metadata.CustomMetadataValue();
a5.field = 'ECOA_Notice__c'; a5.value = 'The Federal Equal Credit Opportunity Act prohibits creditors from discriminating against credit applicants on the basis of race, color, religion, national origin, sex, marital status, age (provided the applicant has the capacity to enter into a binding contract); because all or part of the applicant\'s income derives from any public assistance program; or because the applicant has in good faith exercised any right under the Consumer Credit Protection Act. The Federal agency that administers compliance with this law concerning this creditor is [AGENCY].'; aa.values.add(a5);
Metadata.CustomMetadataValue a6 = new Metadata.CustomMetadataValue();
a6.field = 'Reason_Limit__c'; a6.value = 4; aa.values.add(a6);
Metadata.CustomMetadataValue a7 = new Metadata.CustomMetadataValue();
a7.field = 'Notice_Window_Days__c'; a7.value = 30; aa.values.add(a7);
container.addMetadata(aa);

Id jobId = Metadata.Operations.enqueueDeployment(container, null);
System.debug('CMDT_DEPLOY_JOB=' + jobId);
