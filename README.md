Salesforce-Bulk-MergeNPSP-ServiceManagement
====================

Setup Steps after Deployment

## Deploy Project

Deploy to Production or Sandbox using; cci task run deploy

## Setup Schedules

    ```
      - Open Developer Console
      - Debug Menu select Open Execute Anonymous Window (CTRL+E)
      - Paste the following rules then click Execute

      C501_SM_Rule_Contact_NameDOBFullHH contactNameDOBFullHH = new C501_SM_Rule_Contact_NameDOBFullHH();
      contactNameDOBFullHH.execute(null);
      C501_SM_Rule_Contact_NameDOB contactNameDOB = new C501_SM_Rule_Contact_NameDOB();
      contactNameDOB.execute(null);
      C501_SM_Rule_Contact_NameDOBService contactNameDOBService = new C501_SM_Rule_Contact_NameDOBService();
      contactNameDOBService.execute(null);

    ```

## Enable Merge Metrics

- Select the Mass Merge Application
- Select Merge Metrics
- Change List View to All

You should now see the new rules (e.g., Merge Metric names)

- Select a rule that you want to Enable, open the Rule and check Enable & Save.  Repeat for any other rules you want to enable
- Select a rule that you want to enable Automated Merging.  Set the AutoMerge Percentage which is the threshold for any potential merge found with Confidence greater or equal to the AutoMerge percentage will be automatically merge when the daily schedule runs.  The Merge Metric has the acive confidence value which means when the daily schedule runs any potential merges found based on this rule will get that confidence value.  The confidence value on a rule can change as you set more and more potential merges found by this rule to Ignore in the Mass Merge screen.

## Rule Definitions

* Contact_NameDOB - FirstName Initial, LastName, Birthdate, and Gender must match between 2 Service Contacts on different Service Households only for Service Households where the Program is in the list of Enabled Programs on the rule.
* Contact_NameDOBFullHH - FirstName Initial, LastName, Birthdate, and Gender must match between 2 Service Contacts on different Service Households where the Program is in the list of Enabled Programs on the rule..  In additional all the Service Contacts between the 2 Service Households need to match on FirstName Initial, LastName, Birthdate, and Gender.
* Contact_NameDOBService - FirstName Initial, LastName, Birthdate, and Gender must match between 2 Service Contacts on different Service Households where the Program is in the list of Enabled Programs on the rule.  Additionally the 2 Service Households must have the same Service Start Date.
