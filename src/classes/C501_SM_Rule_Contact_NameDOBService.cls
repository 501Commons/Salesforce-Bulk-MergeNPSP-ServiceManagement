//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
    C501_SM_Rule_Contact_NameDOBService contactNameDOBService = new C501_SM_Rule_Contact_NameDOBService();
    contactNameDOBService.execute(null);
*/
//  3) click Execute
//
// Abort scheduled jobs
/*
    List<CronJobDetail> scheduledJobs = [SELECT Id FROM CronJobDetail WHERE Name like 'SM_Contact_%' or Name like 'SM_Account_%'];
    for (CronJobDetail scheduledJob :scheduledJobs) {
        Id jobId = [SELECT Id FROM CronTrigger WHERE CronJobDetailId = :scheduledJob.Id].Id;
        System.abortJob(jobId);
    }
*/
//
// Schedule Code FROM Developer Console
/*
    integer numSchedules = 30;
    for (integer i = 0; i < numSchedules; i++) {
        system.schedule('Contact_NameDOBService_' + String.valueOf(i * 2), '0 ' + String.valueOf(i * 2) + ' * * * ?', new C501_SM_Rule_Contact_NameDOBService());
    }                      

    system.schedule('Contact_NameDOBService_0', '0 0 * * * ?', new C501_SM_Rule_Contact_NameDOBService());

    // Run daily at 1am (second = 0, min = 0, hour = 1)
    system.schedule('Contact_NameDOBService_30', '0 0 1 * * ?', new C501_SM_Rule_Contact_NameDOBService());

*/

global class C501_SM_Rule_Contact_NameDOBService implements Schedulable {

    global void execute(SchedulableContext SC) {

		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        String mergeMetricName = 'SM_Contact_NameDOBService';

        // Get Merge Metric
        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Enabled_Programs__c,
                Id, Name, Confidence__c,
                Total_Merge_Accounts__c, Total_Merge_Contacts__c, Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c
            FROM C501_Merge_Metric__c
            WHERE Name = :mergeMetricName];
        if (mergeMetrics.isEmpty()) {
            mergeMetrics.add( new C501_Merge_Metric__c (
                Name = mergeMetricName,
                Confidence__c = 100.0,
                AutoMerge_Percentage__c = 0.0,
                Description__c = 'FirstName Initial, LastName, Birthdate, and Gender must match between 2 Service Contacts on different Service Households where the Program is in the list of Enabled Programs on the rule.  Additionally the 2 Service Households must have the same Service Start Date.'
            ));

            insert mergeMetrics;
        }

        if (!mergeMetrics[0].Enable__c || String.isEmpty(mergeMetrics[0].Enabled_Programs__c)) {
            return;
        }

        C501_SM_SharedCode c501_SM_SharedCode = new C501_SM_SharedCode();
        c501_SM_SharedCode.ScheduleJobs(mergeMetrics[0]);

        Date dateUnder18 = date.today().addYears(-18);
        List<String> programs = mergeMetrics[0].Enabled_Programs__c.split(';');

        // Workbench Disclaimer - add LIMIT 200 when using query in Workbench
		AggregateResult[] allAggregatedByServiceContacts = [
            SELECT Count(C501_Service_Household_Id__r.C501_Household__c),
                C501_Birthdate__c,
                C501_Gender__c,
                C501_FirstName_Initial__c,
                C501_Last_Name__c,
                C501_Service_Household_Id__r.C501_Start_Date__c,
                MAX(C501_Service_Household_Id__r.C501_Household__c)MaxAccountId,
                MIN(C501_Service_Household_Id__r.C501_Household__c)MinAccountId
            FROM C501_Service_Contact__c
            WHERE C501_FirstName_Initial__c <> ''
                and C501_Last_Name__c <> ''
                and C501_Service_Household_Id__r.C501_Start_Date__c <> null
                and C501_Birthdate__c <> null and C501_Birthdate__c <= :dateUnder18
                and C501_Service_Household_Id__r.C501_Program__c in :programs
            GROUP BY C501_FirstName_Initial__c,
                C501_Last_Name__c,
                C501_Birthdate__c,
                C501_Gender__c,
                C501_Service_Household_Id__r.C501_Start_Date__c
            HAVING Count(C501_Service_Household_Id__r.C501_Household__c) > 1
            ORDER BY Count(C501_Service_Household_Id__r.C501_Household__c) DESC];

        Map<String, C501_Account_Merge__c> mergeAccounts = new Map<String, C501_Account_Merge__c>();
        String uniqueId, maxId, minId;
        for (AggregateResult result :allAggregatedByServiceContacts)  {

            maxId = result.get('MaxAccountId').toString();
            minId = result.get('MinAccountId').toString();

            if (String.isEmpty(maxId) || String.isEmpty(minId) || maxId == minId) {
                continue;
            }

            uniqueId = mergeMetricName + minId + maxId;

            system.debug('***** C501_SM_Rule_Contact_NameDOBService::execute ByContacts Found - maxId: ' + maxId
                + ' minId: ' + minId + ' UniqueId: ' + uniqueId + ' Confidence: ' + mergeMetrics[0].Confidence__c
                + 'MetricId: ' + mergeMetrics[0].Id);

            mergeAccounts.put(uniqueId, new C501_Account_Merge__c(
                Unique_Id__c = uniqueId,
                Merge_Confidence__c = mergeMetrics[0].Confidence__c,
                Account__c = minId,
                Merge_Target_Account__c = maxId,
                Merge_Metric__c = mergeMetrics[0].Id
            ));
        }

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.ProcessMergeCandidates(mergeMetrics[0], mergeAccounts.values());
   }
}