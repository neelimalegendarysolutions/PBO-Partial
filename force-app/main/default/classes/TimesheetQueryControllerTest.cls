@isTest
private class TimesheetQueryControllerTest {

  @testSetup
    static void setupTestData() {
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'test19856user@example.com',
            Alias = 'tuser',
            CommunityNickname = 'testuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id, // Change 'Standard User' to the name of your standard user profile
            LanguageLocaleKey = 'en_US'
        );

        insert testUser;
     

        Jpetto__Pay_Period__c payPeriod = new Jpetto__Pay_Period__c(
            Jpetto__Start_Date__c = Date.parse('06/15/2023'),
            Jpetto__End_Date__c = Date.parse('06/29/2023')
        );
        insert payPeriod;
   

        Jpetto__Timesheet__c timesheet = new Jpetto__Timesheet__c(
            Jpetto__User__c = testUser.Id,
            Jpetto__Pay_Period__c = PayPeriod.Id,
            Jpetto__Active__c = true
        );
        insert timesheet;
        
           Jpetto__Timesheet__c timesheet1 = new Jpetto__Timesheet__c(
            Jpetto__User__c = testUser.Id,
            Jpetto__Pay_Period__c = PayPeriod.Id,
            Jpetto__Active__c = true
        );
        insert timesheet1;
    
    
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
    

        Jpetto__Project__c testProject = new Jpetto__Project__c(
            Jpetto__Client_Account__c = testAccount.Id,
            Name = 'Test Project'
        );
        insert testProject;
    

        Jpetto__Work_Item__c testWorkItem = new Jpetto__Work_Item__c(
            Jpetto__Project__c = testProject.Id
        );
        insert testWorkItem;
  
    

        Jpetto__Timesheet_Entry__c testTimesheetEntry = new Jpetto__Timesheet_Entry__c(
            Jpetto__Work_Item__c = testWorkItem.Id,
            Jpetto__Timesheet__c = timesheet.id,
            Jpetto__Hours__c = 8.0,
            Jpetto__Billable_to_Client__c = true,
            Jpetto__Date_Worked__c = Date.valueOf('2023-06-15')
        );

        insert testTimesheetEntry;
        
           Jpetto__Timesheet_Entry__c testTimesheetEntry1 = new Jpetto__Timesheet_Entry__c(
            Jpetto__Work_Item__c = testWorkItem.Id,
            Jpetto__Timesheet__c = timesheet1.id,
            Jpetto__Hours__c = 8.0,
            Jpetto__Billable_to_Client__c = true,
            Jpetto__Date_Worked__c = Date.valueOf('2023-06-19')
        );

        insert testTimesheetEntry1;
    }
    
        @isTest
    	static void yourTestMethod() {
        // Start Test execution
        Jpetto__Pay_Period__c payPeriod1 =[Select id,Jpetto__Start_Date__c,Jpetto__End_Date__c from Jpetto__Pay_Period__c 
                                           where Jpetto__Start_Date__c =2023-06-15 limit 1];
        Test.startTest();

        TimesheetQueryController.getUniquePayPeriods();
        TimesheetQueryController.aggregate('friday','payPeriod1', '06/15/2023 - 06/29/2023');

        List<String> uniquePayPeriods = TimesheetQueryController.getUniquePayPeriods();
        System.assertEquals(1, uniquePayPeriods.size(), '1 payperiod present , should return 1');

        String aggregatedResult = TimesheetQueryController.aggregate('monday','payPeriod1', '06/15/2023 - 06/29/2023');
  // 		System.assertEquals(51, ((List<Object>)JSON.deserializeUntyped(aggregatedResult)).size(), 'Expected results');

        // Stop Test execution
        TimesheetQueryController.increment();
            Test.stopTest();         
    }
}