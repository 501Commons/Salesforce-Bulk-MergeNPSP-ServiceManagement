public class C501_SM_UnMerge_Controller {

    private final Account unmergeAccount;
    
    public C501_SM_UnMerge_Controller(ApexPages.StandardController stdController) {
        this.unmergeAccount = (Account)stdController.getRecord();
    }

    public PageReference autoRun() {

        // Perform UnMerge
        Boolean firstRecordSkipped = false;
        Id unMergeAccountId = this.unmergeAccount.Id;

        // Ignore Change Requests and Service Households that do not have any Service Contacts
        String strSoql = 'SELECT Id, Name, C501_Household__c';
        strSoql += ' FROM C501_Service_Household__c';
        strSoql += ' WHERE C501_Household__c = :unMergeAccountId and (NOT Name like \'Change Request%\') and C501_Household_Size__c >= 1.0';
        strSoql += ' ORDER BY C501_Start_Date__c DESC';
        List<C501_Service_Household__c> serviceHouseholds = Database.Query(strSoql);

        List<Id> serviceHouseholdIds = new List<Id>();
        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {
            serviceHouseholdIds.add(serviceHousehold.Id);
        }

        Map<Id, List<C501_Service_Contact__c>> serviceContacts = new Map<Id, List<C501_Service_Contact__c>>();
        for (C501_Service_Contact__c serviceContact : [
            SELECT Id, C501_Last_Name__c, C501_Service_Household_Id__c, C501_Contact__c
            FROM C501_Service_Contact__c
            WHERE C501_Service_Household_Id__c in :serviceHouseholdIds]) {

            if (serviceContacts.containsKey(serviceContact.C501_Service_Household_Id__c)) {
                List<C501_Service_Contact__c> existingServiceContacts = serviceContacts.remove(serviceContact.C501_Service_Household_Id__c);
                existingServiceContacts.add(serviceContact);
                serviceContacts.put(serviceContact.C501_Service_Household_Id__c, existingServiceContacts);
            }
            else {
                serviceContacts.put(serviceContact.C501_Service_Household_Id__c, new List<C501_Service_Contact__c> { serviceContact });
            }
        }

        Map<Id, Account> newHouseholds = new Map<Id, Account>();
        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {
            if (!firstRecordSkipped) {
                firstRecordSkipped = true;
                continue;
            }

            newHouseholds.put(
                serviceHousehold.Id,
                new Account(
                    Name = serviceHousehold.Name,
                    C501_Service_Id__c = serviceHousehold.Id));
        }

        if (!newHouseholds.isEmpty()) {
            insert newHouseholds.values();
        }

        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {
            if (newHouseholds.containsKey(serviceHousehold.Id)) {
                serviceHousehold.C501_Household__c = newHouseholds.get(serviceHousehold.Id).Id;
            }
        }

        if (!serviceHouseholds.isEmpty()) {
            update serviceHouseholds;
        }

        Map<Id, Contact> newContacts = new Map<Id, Contact>();
        List<C501_Service_Contact__c> updateServiceContacts = new List<C501_Service_Contact__C>();
        firstRecordSkipped = false;
        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {
            if (!firstRecordSkipped) {
                firstRecordSkipped = true;
                continue;
            }

            if (serviceContacts.containsKey(serviceHousehold.Id))
            {
                for (C501_Service_Contact__c serviceContact :serviceContacts.get(serviceHousehold.Id)) {

                    serviceContact.C501_Contact_Id__c = serviceContact.Id;

                    newContacts.put(
                        serviceContact.Id,
                        new Contact(
                            LastName = serviceContact.C501_Last_Name__c,
                            AccountId = serviceHousehold.C501_Household__c,
                            C501_Contact_Id__c = serviceContact.Id,
                            C501_Service_Id__c = serviceHousehold.Id));
                }
            }
        }

        if (!newContacts.values().isEmpty()) {
            insert newContacts.values();
        }

        Map<Id, Id> changedContactIds = new Map<Id, Id>();
        for (List<C501_Service_Contact__c> serviceContactsById :serviceContacts.values()) {
            for (C501_Service_Contact__c serviceContact : serviceContactsById) {
                updateServiceContacts.add(serviceContact);
                if (newContacts.containsKey(serviceContact.Id)) {
                    if (serviceContact.C501_Contact__c != null) {
                        changedContactIds.put(serviceContact.C501_Contact__c, newContacts.get(serviceContact.Id).Id);
                    }
                    serviceContact.C501_Contact__c = newContacts.get(serviceContact.Id).Id;
                }
            }
        }

        if (!updateServiceContacts.isEmpty()) {
            update updateServiceContacts;
        }

        // Check to merge any Contacts that no longer have a Service Contact record
        if (!changedContactIds.isEmpty()) {
            for (C501_Service_Contact__c contactReferenced : [
                SELECT C501_Contact__c
                FROM C501_Service_Contact__c
                WHERE C501_Contact__c in :changedContactIds.keySet()]) {
                    changedContactIds.remove(contactReferenced.C501_Contact__c);
                }
        }

        for (Id contactId :changedContactIds.keySet()) {
            Database.merge(new Contact(Id = changedContactIds.get(contactId)), new Contact (Id = contactId), false);
        }

        // Trigger reload original account page
        PageReference accountPage = new PageReference('/' + this.unmergeAccount.Id);
        accountPage.setRedirect(true);
        return accountPage;
    }
}