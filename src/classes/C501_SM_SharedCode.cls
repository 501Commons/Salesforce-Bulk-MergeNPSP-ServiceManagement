global with sharing class C501_SM_SharedCode {

    global void ScheduleJobs() {

        List<CronJobDetail> cronJobDetails = [SELECT Id, JobType, Name FROM CronJobDetail];
        List<String> mergeMetricNames = new List<String> { 'SM_Contact_NameDOB', 'SM_Contact_NameDOBFullHH', 'SM_Contact_NameDOBService' };
        for (String mergeMetricName :mergeMetricNames) {

            Boolean foundMergeMetricName = false;
            for (CronJobDetail jobDetail :cronJobDetails) {
                if (jobDetail.Name.contains(mergeMetricName)) {
                    foundMergeMetricName = true;
                    break;
                }
            }

            if (!foundMergeMetricName) {

                // Run every 5 minutes if there are more than 100 pending merges based on the automerge percentage otherwise set to hourly (abort all other hourly scheduled jobs except 0 one)
                // Check scheduled jobs limits - online thread mentioned 100
                // Salesforce only supports hourly not minute interval format 0 0/5 00 for s m h not supported which is every 5 minutes
                String cronExpression, mergeMetricNameSchedule;
                for (integer i = 0; i <= 55; i += 5) {
                    cronExpression = '0 ' + String.valueOf(i) + ' * * * ?';
                    mergeMetricNameSchedule = mergeMetricName + '_' + String.valueOf(i);

                    if (mergeMetricName == 'SM_Contact_NameDOB') {
                        System.schedule(mergeMetricNameSchedule, cronExpression, new C501_SM_Rule_Contact_NameDOB());
                    }
                    else if (mergeMetricName == 'SM_Contact_NameDOBFullHH') {
                        System.schedule(mergeMetricNameSchedule, cronExpression, new C501_SM_Rule_Contact_NameDOBFullHH());
                    }
                    else if (mergeMetricName == 'SM_Contact_NameDOBService') {
                        System.schedule(mergeMetricNameSchedule, cronExpression, new C501_SM_Rule_Contact_NameDOBService());
                    }
                }
            }
        }
    }
}
