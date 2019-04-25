public class C501_SM_UnMerge_Controller {

    private final Account unmergeAccount;
    
    public C501_SM_UnMerge_Controller(ApexPages.StandardController stdController) {
        this.unmergeAccount = (Account)stdController.getRecord();
    }

    public PageReference autoRun() {

        // Perform UnMerge
        Id unMergeAccountId = this.unmergeAccount.Id;

        // Ignore Change Requests and Service Households that do not have any Service Contacts
        String strSoql = 'SELECT Id, Name, C501_Household__c, C501_Service_Id__c';
        strSoql += ' FROM C501_Service_Household__c';
        strSoql += ' WHERE C501_Household__c = :unMergeAccountId and (NOT Name like \'Change Request%\') and C501_Household_Size__c >= 1.0';
        strSoql += ' ORDER BY C501_Start_Date__c DESC';
        List<C501_Service_Household__c> serviceHouseholds = Database.Query(strSoql);

        Set<Id> serviceHouseholdIds = new Set<Id>();
        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {
            serviceHouseholdIds.add(serviceHousehold.Id);
        }

        // Build list of all service contacts by service household
        Map<Id, Set<C501_Service_Contact__c>> serviceContacts = new Map<Id, Set<C501_Service_Contact__c>>();
        for (C501_Service_Contact__c serviceContact : [
            SELECT Id, C501_Last_Name__c, C501_Service_Household_Id__c, C501_Contact__c
            FROM C501_Service_Contact__c
            WHERE C501_Service_Household_Id__c in :serviceHouseholdIds]) {

            if (serviceContacts.containsKey(serviceContact.C501_Service_Household_Id__c)) {
                Set<C501_Service_Contact__c> existingServiceContacts = serviceContacts.remove(serviceContact.C501_Service_Household_Id__c);
                existingServiceContacts.add(serviceContact);
                serviceContacts.put(serviceContact.C501_Service_Household_Id__c, existingServiceContacts);
            }
            else {
                serviceContacts.put(serviceContact.C501_Service_Household_Id__c, new Set<C501_Service_Contact__c> { serviceContact });
            }
        }

        // Create new households so each household has a single service household
        Map<Id, Account> newHouseholds = new Map<Id, Account>();
        Id skippedServiceHouseholdId = null;
        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {

            if (skippedServiceHouseholdId == null) {
                skippedServiceHouseholdId = serviceHousehold.Id;
                continue;
            }

            newHouseholds.put(
                serviceHousehold.Id,
                new Account(
                    Name = serviceHousehold.Name,
                    C501_Service_Id__c = serviceHousehold.C501_Service_Id__c));
        }

        if (!newHouseholds.values().isEmpty()) {
            insert newHouseholds.values();
        }

        // Update service household reference to the new household
        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {
            if (newHouseholds.containsKey(serviceHousehold.Id)) {
                serviceHousehold.C501_Household__c = newHouseholds.get(serviceHousehold.Id).Id;
            }
        }

        if (!serviceHouseholds.isEmpty()) {
            update serviceHouseholds;
        }

        // Create new contact(s) in the new household(s)
        Map<Id, Contact> newContacts = new Map<Id, Contact>();
        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {

            if (skippedServiceHouseholdId == serviceHousehold.Id) {
                continue;
            }

            if (serviceContacts.containsKey(serviceHousehold.Id))
            {
                for (C501_Service_Contact__c serviceContact :serviceContacts.get(serviceHousehold.Id)) {

                    newContacts.put(
                        serviceContact.Id,
                        new Contact(
                            LastName = serviceContact.C501_Last_Name__c,
                            AccountId = serviceHousehold.C501_Household__c

                            // Why do you even have these fields? - should be removed because they mean nothing after merging
                            //C501_Contact_Id__c = serviceContact.Id,
                            //C501_Service_Id__c = serviceHousehold.Id
                            ));
                }
            }
        }

        if (!newContacts.values().isEmpty()) {
            insert newContacts.values();
        }

        // Update service contact with new contact id
        List<C501_Service_Contact__c> updateServiceContacts = new List<C501_Service_Contact__c>();
        for (Id serviceContactId :newContacts.keyset()) {
            updateServiceContacts.add(new C501_Service_Contact__c(
                Id = serviceContactId,
                C501_Contact__c = newContacts.get(serviceContactId).Id
            ));
        }

        if (!updateServiceContacts.isEmpty()) {
            update updateServiceContacts;
        }

        // Trigger reload original account page
        PageReference accountPage = new PageReference('/' + this.unmergeAccount.Id);
        accountPage.setRedirect(true);
        return accountPage;
    }
}