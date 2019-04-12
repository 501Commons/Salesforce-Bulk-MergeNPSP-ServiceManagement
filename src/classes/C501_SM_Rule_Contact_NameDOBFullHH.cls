//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_SM_Rule_Contact_NameDOBFullHH NameDOBFullHH = new C501_SM_Rule_Contact_NameDOBFullHH();
      NameDOBFullHH.execute(null);
*/
//  3) click Execute
//

global class C501_SM_Rule_Contact_NameDOBFullHH implements Schedulable {

    global void execute(SchedulableContext SC) {

        system.debug('***** C501_SM_Rule_Contact_NameDOBFullHH:execute');

		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        String mergeMetricName = 'SM_Contact_NameDOBFullHH';

        // Get Merge Metric
        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Enabled_Programs__c,
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c
            FROM C501_Merge_Metric__c
            WHERE Name = :mergeMetricName];
        if (mergeMetrics.isEmpty()) {
            mergeMetrics.add( new C501_Merge_Metric__c (
                Name = mergeMetricName,
                Confidence__c = 100.0,
                AutoMerge_Percentage__c = 0.0,
                Description__c = 'FirstName Initial, LastName, Birthdate, and Gender must match between 2 Service Contacts on different Service Households where the Program is in the list of Enabled Programs on the rule..  In additional all the Service Contacts between the 2 Service Households need to match on FirstName Initial, LastName, Birthdate, and Gender.'
            ));

            insert mergeMetrics;
        }

        if (!mergeMetrics[0].Enable__c || String.isEmpty(mergeMetrics[0].Enabled_Programs__c)) {
            return;
        }

        C501_SM_SharedCode c501_SM_SharedCode = new C501_SM_SharedCode();
        c501_SM_SharedCode.ScheduleJobs(mergeMetrics[0]);

        List<String> programs = mergeMetrics[0].Enabled_Programs__c.split(';');
        system.debug('***** C501_SM_Rule_Contact_NameDOBFullHH:execute - Enabled_Programs__c: ' + String.valueOf(programs));

        //
        // Testing in Workbench tips
        //
        //      and C501_Birthdate__c <> null and C501_Birthdate__c < 2000-01-01
        //      and C501_Service_Household_Id__r.C501_Program__c in ('Energy Assistance','Housing Pool')
        // add LIMIT 10 at the end

		AggregateResult[] allAggregatedByServiceContacts = [
            SELECT Count(C501_Service_Household_Id__r.C501_Household__c),
                C501_Birthdate__c,
                C501_Gender__c,
                C501_FirstName_Initial__c,
                C501_Last_Name__c,
                MAX(C501_Service_Household_Id__r.C501_Household__c)MaxAccountId,
                MIN(C501_Service_Household_Id__r.C501_Household__c)MinAccountId
            FROM C501_Service_Contact__c
            WHERE C501_FirstName_Initial__c <> null
                and C501_Last_Name__c <> null
                and C501_Birthdate__c <> null
                and C501_Service_Household_Id__r.C501_Program__c in :programs
            GROUP BY C501_FirstName_Initial__c,
                C501_Last_Name__c,
                C501_Birthdate__c,
                C501_Gender__c
            HAVING Count(C501_Service_Household_Id__r.C501_Household__c) > 1
            ORDER BY Count(C501_Service_Household_Id__r.C501_Household__c) DESC];

        Set<Id> mergeAccountIds = new Set<Id>();
        String minId, maxId;
        for (AggregateResult result : allAggregatedByServiceContacts)  {
            
            maxId = result.get('MaxAccountId').toString();
            minId = result.get('MinAccountId').toString();

            if (String.isEmpty(maxId) || String.isEmpty(minId) || maxId == minId) {
                continue;
            }

            mergeAccountIds.add(maxId);
            mergeAccountIds.add(minId);
        }

        List<Contact> contacts = [
            SELECT AccountId, FirstName, LastName, Birthdate, Gender__c
            FROM Contact
            WHERE
                AccountId in :mergeAccountIds
                and FirstName <> null 
                and Birthdate <> null 
                and Gender__c <> null
            ORDER BY AccountId, FirstName, LastName, Birthdate, Gender__c DESC];

        if (contacts.isEmpty()) {
            return;
        }

        Map<Id,String> accountContacts = new Map<Id,String>();
        for (Contact contactInfo :contacts) {
            String contactsInfo;
            if (accountContacts.containsKey(contactInfo.AccountId)) {
                contactsInfo = accountContacts.remove(contactInfo.AccountId);
            }

            contactsInfo += contactInfo.FirstName.mid(1,1) + contactInfo.LastName + contactinfo.Birthdate + contactInfo.Gender__c;
            accountContacts.put(contactInfo.AccountId, contactsInfo);
        }

        Map<String, C501_Account_Merge__c> mergeAccounts = new Map<String, C501_Account_Merge__c>();
        String uniqueId;
        for (AggregateResult result : allAggregatedByServiceContacts)  {
            maxId = result.get('MaxAccountId').toString();
            minId = result.get('MinAccountId').toString();

            if (String.isEmpty(maxId) || String.isEmpty(minId) || maxId == minId) {
                continue;
            }

            if (!mergeAccountIds.contains(maxId) || !mergeAccountIds.contains(minId) || !accountContacts.containsKey(maxId) || !accountContacts.containsKey(minId)) {
                continue;
            }

            // Validate Contacts same between both accounts
            if (accountContacts.get(maxId) <> accountContacts.get(minId)) {
                continue;
            }

            uniqueId = mergeMetricName + maxId + minId;
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