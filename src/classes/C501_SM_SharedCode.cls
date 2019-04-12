global with sharing class C501_SM_SharedCode {

    global void ScheduleJobs(C501_Merge_Metric__c mergeMetric) {

        // Hourly Offset to try to avoid rules running at the same time
        Integer hourlyOffset = 0;
        if (mergeMetric.Name == 'SM_Contact_NameDOB') {
            hourlyOffset = 1;
        }
        else if (mergeMetric.Name == 'SM_Contact_NameDOBFullHH') {
            hourlyOffset = 2;
        }
        else if (mergeMetric.Name == 'SM_Contact_NameDOBService') {
            hourlyOffset = 4;
        }

        Boolean hourlySyncOnly = true;

        if (mergeMetric.AutoMerge_Percentage__c <> null && mergeMetric.AutoMerge_Percentage__c > 0.0) {
            List<String> automergeObjects = mergeMetric.AutoMerge_Objects__c.split(';');

            if (automergeObjects.contains('Contact') && mergeMetric.Total_Unassigned_Contacts__c > 0) {
                hourlySyncOnly = false;
            }

            if (automergeObjects.contains('Account') && mergeMetric.Total_Unassigned_Accounts__c > 0) {
                hourlySyncOnly = false;
            }
        }

        List<CronJobDetail> cronJobDetails = [SELECT Id, JobType, Name FROM CronJobDetail];
        List<CronTrigger> cronTriggers = [SELECT Id, CronJobDetailId FROM CronTrigger];

        Boolean foundHourlySyncTrigger = false, foundAdditionalSyncTriggers = false;
        for (CronJobDetail jobDetail :cronJobDetails) {

            // Check for hourly trigger
            if (jobDetail.Name.equals(mergeMetric.Name + '_0')) {
                foundHourlySyncTrigger = true;
            }
            else if (jobDetail.Name.startsWith(mergeMetric.Name + '_')) {

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

            Integer triggerNumber = 0;
            for (integer i = hourlyOffset; i <= 59; i += 5) {
                cronExpression = '0 ' + String.valueOf(i) + ' * * * ?';
                mergeMetricNameSchedule = mergeMetric.Name + '_' + String.valueOf(triggerNumber++);

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