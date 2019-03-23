@isTest
private with sharing class C501_SM_UnMerge_Controller_TEST {
    
    @testSetup static void setup() {
    }

    //==================== TEST METHOD(s) ======================================

    private static testmethod void UnMergeControllerTests() {

        Account unmergeAccount = new Account(
            Name = 'Account Name'
        );
        insert unmergeAccount;

        ApexPages.StandardController standardController = new ApexPages.StandardController(unmergeAccount);
        C501_SM_UnMerge_Controller controller = new C501_SM_UnMerge_Controller(standardController);
        controller.autoRun();

        // other code to assert stuff
    }
}