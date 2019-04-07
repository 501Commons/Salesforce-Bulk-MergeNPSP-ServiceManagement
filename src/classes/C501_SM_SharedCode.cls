global with sharing class C501_SM_SharedCode {

    global void ScheduleJobs(C501_Merge_Metric__c mergeMetric) {

        // Offset by 2 to stagger with Merge NPSP rules
        Integer hourlyOffset = 2;
        Boolean hourlySyncOnly = false;

        if (mergeMetric.AutoMerge_Percentage__c == null || mergeMetric.AutoMerge_Percentage__c <= 0.0 || ((mergeMetric.Total_Unassigned_Accounts__c + mergeMetric.Total_Unassigned_Contacts__c) < 100)) {
            hourlySyncOnly = true;
        }

        List<CronJobDetail> cronJobDetails = [SELECT Id, JobType, Name FROM CronJobDetail];
        List<CronTrigger> cronTriggers = [SELECT Id, CronJobDetailId FROM CronTrigger];

        Boolean foundHourlySyncTrigger = false, foundAdditionalSyncTriggers = false;
        for (CronJobDetail jobDetail :cronJobDetails) {

            // Check for hourly trigger
            if (jobDetail.Name.equals(mergeMetric.Name + '_' + String.valueOf(hourlyOffset))) {
                foundHourlySyncTrigger = true;
            }
            else if (jobDetail.Name.startsWith(mergeMetric.Name)) {

                foundAdditionalSyncTriggers = true;
                if (hourlySyncOnly) {
                    for (CronTrigger cronTrigger :cronTriggers) {
                        
                        // Stop Sync
                        if (cronTrigger.CronJobDetailId == jobDetail.Id) {
                            System.abortJob(cronTrigger.Id);
                        }
                    }
                }
            }
        }

        if (!foundHourlySyncTrigger || !foundAdditionalSyncTriggers) {

            // Run every 5 minutes if there are more than 100 pending merges based on the automerge percentage otherwise set to hourly (abort all other hourly scheduled jobs except 0 one)
            // Check scheduled jobs limits - online thread mentioned 100
            // Salesforce only supports hourly not minute interval format 0 0/5 00 for s m h not supported which is every 5 minutes
            String cronExpression, mergeMetricNameSchedule;

            for (integer i = hourlyOffset; i <= 59; i += 5) {
                cronExpression = '0 ' + String.valueOf(i) + ' * * * ?';
                mergeMetricNameSchedule = mergeMetric.Name + '_' + String.valueOf(i);

                // Check if Hourly Sync Trigger already created
                if (foundHourlySyncTrigger && i == hourlyOffset) {

                    if (hourlySyncOnly || foundAdditionalSyncTriggers) {
                        break;
                    }

                    continue;
                }

                if (mergeMetric.Name == 'SM_Contact_NameDOB') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_SM_Rule_Contact_NameDOB());
                }
                else if (mergeMetric.Name == 'SM_Contact_NameDOBFullHH') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_SM_Rule_Contact_NameDOBFullHH());
                }
                else if (mergeMetric.Name == 'SM_Contact_NameDOBService') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_SM_Rule_Contact_NameDOBService());
                }

                if (hourlySyncOnly || foundAdditionalSyncTriggers) {
                    break;
                }
            }
        }
    }
}