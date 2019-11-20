public class C501_SM_UnMerge_Controller {

    private final Account unMergeAccount;
    
    public C501_SM_UnMerge_Controller(ApexPages.StandardController stdController) {
        this.unMergeAccount = (Account)stdController.getRecord();
    }

    public PageReference autoRun() {

        Account unMergeAccount = [SELECT Id, Name FROM Account WHERE Id = :this.unMergeAccount.Id LIMIT 1];

        // Unmerge all the Service Households
        List<C501_Service_Household__c> serviceHouseholds = this.UnMergeServiceHouseholds(unMergeAccount);

        // Unmerge all the Service Contacts
        this.UnMergeServiceContacts(unMergeAccount, serviceHouseholds);

        // Trigger reload original account page
        PageReference accountPage = new PageReference('/' + unMergeAccount.Id);
        accountPage.setRedirect(true);
        return accountPage;
    }

    //
    //  UnMergeServiceHouseholds
    //      params: unMergeAccount - the Account to unmerge
    //      return: List<C501_Service_Household__c> - list of all the created Service Households
    //
    private List<C501_Service_Household__c> UnMergeServiceHouseholds(Account unMergeAccount) {

        // Get related Service Households
        //
        String strSoql = 'SELECT Id, Name, C501_Household__c, C501_Service_Id__c';
        strSoql += ' FROM C501_Service_Household__c';
        strSoql += ' WHERE C501_Household__c = \'' + String.valueOf(unMergeAccount.Id) + '\'';
        strSoql += ' AND (NOT Name like \'Change Request%\')';
        strSoql += ' AND C501_Program__c <> \'Information & Referral\'';
        strSoql += ' ORDER BY C501_Start_Date__c DESC';

        System.debug(LoggingLevel.DEBUG, '*****C501_SM_UnMerge_Controller::UnMergeServiceHouseholds strSoql: ' + strSoql);

        Map<Id, C501_Service_Household__c> serviceHouseholdsMap = new Map<Id, C501_Service_Household__c>();
        for (C501_Service_Household__c serviceHousehold : Database.Query(strSoql)) {
            serviceHouseholdsMap.put(serviceHousehold.Id, serviceHousehold);
        }

        if (serviceHouseholdsMap.values().isEmpty()) {
            return new List<C501_Service_Household__c>();
        }

        // Create new households so each household has a single service household
        //
        this.unMergeAccount.C501_Service_Id__c = null;
        Map<Id, Account> insertHouseholds = new Map<Id, Account>();
        for (C501_Service_Household__c serviceHousehold :serviceHouseholdsMap.values()) {

            // Keep the most recent Service Household on the incoming unmerge Account
            if (this.unMergeAccount.C501_Service_Id__c == null) {

                this.unMergeAccount.C501_Service_Id__c = serviceHousehold.Id;
                update unMergeAccount;

                continue;
            }

            insertHouseholds.put(
                serviceHousehold.Id,
                new Account(
                    Name = unMergeAccount.Name,
                    C501_Service_Id__c = serviceHousehold.Id));
        }

        if (!insertHouseholds.values().isEmpty()) {
            insert insertHouseholds.values();
        }

        // Update service household reference to the new household
        List<C501_Service_Household__c> updateServiceHouseholds = new List<C501_Service_Household__c>();
        for (Id serviceHouseholdId :insertHouseholds.keySet()) {
            updateServiceHouseholds.add(new C501_Service_Household__c(
                Id = serviceHouseholdId,
                C501_Household__c = insertHouseholds.get(serviceHouseholdId).Id));
        }

        if (!updateServiceHouseholds.isEmpty()) {
            update updateServiceHouseholds;
        }

        return updateServiceHouseholds;
    }

    private void CheckOrphanedContacts(Account unMergeAccount) {

        // Get related Service Households
        //
        String strSoql = 'SELECT Id';
        strSoql += ' FROM C501_Service_Household__c';
        strSoql += ' WHERE C501_Household__c = \'' + String.valueOf(unMergeAccount.Id) + '\'';
        strSoql += ' AND (NOT Name like \'Change Request%\')';
        strSoql += ' AND C501_Program__c <> \'Information & Referral\'';
        strSoql += ' ORDER BY C501_Start_Date__c DESC';

        System.debug(LoggingLevel.DEBUG, '*****C501_SM_UnMerge_Controller::CheckOrphanedContacts C501_Service_Household__c strSoql: ' + strSoql);

        List<Id> serviceHouseholdIds = new List<Id>();
        for (C501_Service_Household__c serviceHousehold : Database.Query(strSoql)) {
            serviceHouseholdIds.add(serviceHousehold.Id);
        }

        if (serviceHouseholdIds.isEmpty()) {
            return;
        }

        String safeSoqlList = '(\'' + String.join(serviceHouseholdIds, '\',\'') + '\')';

        // Get related Service Contacts
        //
        strSoql = 'SELECT C501_Contact__c ';
        strSoql += ' FROM C501_Service_Contact__c';
        strSoql += ' WHERE C501_Service_Household_Id__c in ' + safeSoqlList;
        strSoql += ' ORDER BY CreatedDate DESC';

        System.debug(LoggingLevel.DEBUG, '*****C501_SM_UnMerge_Controller::CheckOrphanedContacts C501_Service_Contact__c strSoql: ' + strSoql);

        Set<Id> contactIds = new Set<Id>();
        for (C501_Service_Contact__c serviceContact : Database.Query(strSoql)) {
            contactIds.add(serviceContact.C501_Contact__c);
        }

        // Get related Service Contacts
        //
        strSoql = 'SELECT Id ';
        strSoql += ' FROM Contact';
        strSoql += ' WHERE AccountId = \'' + unMergeAccount.Id + '\'';

        System.debug(LoggingLevel.DEBUG, '*****C501_SM_UnMerge_Controller::CheckOrphanedContacts Contact strSoql: ' + strSoql);

        List<Contact> deleteContacts = new List<Contact>();
        List<Id> deleteContactIds = new List<Id>();
        for (Contact contactRecord : Database.Query(strSoql)) {
            if (!contactIds.contains(contactRecord.Id)) {
                deleteContactIds.add(contactRecord.Id);
                deleteContacts.add(contactRecord);
            }
        }

        if (!deleteContacts.isEmpty()) {

            safeSoqlList = '(\'' + String.join(deleteContactIds, '\',\'') + '\')';

            // Get related Service Contacts
            //
            strSoql = 'SELECT Id ';
            strSoql += ' FROM C501_Service_Contact__c';
            strSoql += ' WHERE C501_Contact__c in ' + safeSoqlList;

            System.debug(LoggingLevel.DEBUG, '*****C501_SM_UnMerge_Controller::CheckOrphanedContacts deleteServiceContacts strSoql: ' + strSoql);

            List<C501_Service_Contact__c> deleteServiceContacts = Database.Query(strSoql);
            if (!deleteServiceContacts.isEmpty()) {
                System.debug(LoggingLevel.DEBUG, '*****C501_SM_UnMerge_Controller::CheckOrphanedContacts deleteServiceContacts: ' + deleteServiceContacts);
                delete deleteServiceContacts;
            }

            System.debug(LoggingLevel.DEBUG, '*****C501_SM_UnMerge_Controller::CheckOrphanedContacts deleteContacts: ' + deleteContacts);
            delete deleteContacts;
        }
    }

    //
    //  UnMergeServiceContacts
    //      params: serviceHouseholds - list of all service households that were created during the unmerge
    //      return: void
    //
    private void UnMergeServiceContacts(Account unMergeAccount, List<C501_Service_Household__c> serviceHouseholds) {

        // Check orphaned contacts - no service contact related to service programs
        this.CheckOrphanedContacts(unMergeAccount);

        if (serviceHouseholds.isEmpty()) {
            return;
        }

        List<String> serviceHouseholdIds = new List<String>();
        for (C501_Service_Household__c serviceHousehold :serviceHouseholds) {
            serviceHouseholdIds.add((String)serviceHousehold.Id);
        }

        String safeSoqlList = '(\'' + String.join(serviceHouseholdIds, '\',\'') + '\')';

        // Get related Service Contacts
        //
        String strSoql = 'SELECT Id, Name, C501_Last_Name__c, C501_First_Name__c, ';
        strSoql += ' C501_Contact__c, C501_Contact_Id__c,';
        strSoql += ' C501_Service_Household_Id__c, C501_Service_Id__c';
        strSoql += ' FROM C501_Service_Contact__c';
        strSoql += ' WHERE C501_Service_Household_Id__c in ' + safeSoqlList;
        strSoql += ' ORDER BY CreatedDate DESC';

        System.debug(LoggingLevel.DEBUG, '*****C501_SM_UnMerge_Controller::UnMergeServiceContacts strSoql: ' + strSoql);

        Map<Id, C501_Service_Contact__c> serviceContactsMap = new Map<Id, C501_Service_Contact__c>();
        Map<Id, Id> serviceHouseholdMap = new Map<Id, Id>();
        for (C501_Service_Contact__c serviceContact : Database.Query(strSoql)) {

            serviceContactsMap.put(serviceContact.Id, serviceContact);

            for (C501_Service_Household__c serviceHousehold : serviceHouseholds) {
                if (serviceHousehold.Id == serviceContact.C501_Service_Household_Id__c) {
                    serviceHouseholdMap.put(serviceContact.C501_Service_Household_Id__c, serviceHousehold.C501_Household__c);
                    break;
                }
            }
        }

        if (serviceContactsMap.values().isEmpty()) {
            return;
        }

        // Create new Contacts for each Service Contact
        //
        Map<Id, Contact> insertContactsMap = new Map<Id, Contact>();
        Map<Id, Account> updateAccountsMap = new Map<Id, Account>();
        for (C501_Service_Contact__c serviceContact :serviceContactsMap.values()) {

            Id accountId = serviceHouseholdMap.get(serviceContact.C501_Service_Household_Id__c);

            insertContactsMap.put(
                serviceContact.Id,
                new Contact(
                    LastName = serviceContact.C501_Last_Name__c,
                    FirstName = serviceContact.C501_First_Name__c,
                    AccountId = accountId,
                    C501_Contact_Id__c = serviceContact.Id));

            updateAccountsMap.put(
                accountId,
                new Account(
                    Id = accountId,
                    Name = unMergeAccount.Name
            ));
        }

        if (!insertContactsMap.values().isEmpty()) {
            insert insertContactsMap.values();
        }

        // Propegate Account name from unMerge Account
        if (!updateAccountsMap.values().isEmpty()) {
            update updateAccountsMap.values();
        }

        // Update Service Contact reference to the new Contact
        List<C501_Service_Contact__c> updateServiceContacts = new List<C501_Service_Contact__c>();
        for (Id serviceContactId :insertContactsMap.keySet()) {
            updateServiceContacts.add(new C501_Service_Contact__c(
                Id = serviceContactId,
                C501_Contact__c = insertContactsMap.get(serviceContactId).Id));
        }

        if (!updateServiceContacts.isEmpty()) {
            update updateServiceContacts;
        }

        // Check orphaned contacts - no service contact related to service programs
        this.CheckOrphanedContacts(unMergeAccount);
    }    
}