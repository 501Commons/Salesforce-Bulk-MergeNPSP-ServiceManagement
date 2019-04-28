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
   }
}