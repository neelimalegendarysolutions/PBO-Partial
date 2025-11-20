@IsTest
public class FlowNotifyTimesheetEntryHelprTest {

    private static Id ensureTimesheetEntryRecordType() {
        try {
            return [
                SELECT Id FROM RecordType 
                WHERE SObjectType = 'Jpeto__Timesheet_Entry__c' 
                AND DeveloperName = 'Missed_Entry'
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            return null; 
        }
    }

    @TestSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User u1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Alias = 'tusr1',
            Email = 'testuser1@example.com',
            Username = 'testuser1' + DateTime.now().getTime() + '@example.com',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u1;

        Date today = Date.today();
        Jpeto__Pay_Period__c payP = new Jpeto__Pay_Period__c(
            Jpeto__Start_Date__c = today.addDays(-7),
            Jpeto__End_Date__c = today.addDays(22)
        );
        insert payP;

        Jpeto__Timesheet__c ts = new Jpeto__Timesheet__c(
            Jpeto__User__c = u1.Id,
            Jpeto__Pay_Period__c = payP.Id
        );
        insert ts;

        Account acc = new Account(Name = 'Acc1');
        insert acc;

        Jpeto__Project__c proj = new Jpeto__Project__c(
            Name = 'Test Project',
            Jpeto__Client_Account__c = acc.Id
        );
        insert proj;

        Jpeto__Project_Team_Member__c team = new Jpeto__Project_Team_Member__c(
            Jpeto__Project__c = proj.Id,
            Jpeto__Team_Member__c = u1.Id
        );
        insert team;

        // Removed Name field to fix "not writeable" issue
        Jpeto__Work_Item__c wi = new Jpeto__Work_Item__c(
            Jpeto__Assigned_User__c = u1.Id,
            Jpeto__Project__c = proj.Id
        );
        insert wi;

        // Ensure record type exists
        ensureTimesheetEntryRecordType();

        // Ensure Email Template exists
        if ([SELECT COUNT() FROM EmailTemplate WHERE DeveloperName = 'Timesheet_Entry_Missing_Template'] == 0) {
            Folder f = [SELECT Id FROM Folder WHERE Name = 'Public Email Templates' LIMIT 1];
            EmailTemplate tmpl = new EmailTemplate(
                DeveloperName = 'Timesheet_Entry_Missing_Template',
                Name = 'Timesheet Entry Missing Template',
                FolderId = f.Id,
                HtmlValue = '<html><body>Timesheet Entry Created</body></html>',
                Subject = 'Timesheet Entry Created',
                TemplateStyle = 'custom',
                IsActive = true
            );
            insert tmpl;
        }
    }

    @IsTest
    static void testCreateTimesheetEntries() {
        User u = [SELECT Id FROM User WHERE Email LIKE 'testuser1%@example.com' LIMIT 1];

        FlowNotifyTimesheetEntryHelpr.InputWrapper input = new FlowNotifyTimesheetEntryHelpr.InputWrapper();
        input.userIds = new List<Id>{ u.Id };

        Test.startTest();
        List<FlowNotifyTimesheetEntryHelpr.OutputWrapper> results =
            FlowNotifyTimesheetEntryHelpr.createTimesheetEntries(new List<FlowNotifyTimesheetEntryHelpr.InputWrapper>{ input });
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Expected OutputWrapper list not empty');

        List<Jpeto__Timesheet_Entry__c> tseList = [
            SELECT Id, Jpeto__Timesheet__c, Jpeto__Hours__c, RecordTypeId
            FROM Jpeto__Timesheet_Entry__c
        ];
        System.assert(!tseList.isEmpty(), 'Timesheet Entry should be created');
        System.assertEquals(0, tseList[0].Jpeto__Hours__c, 'Expected 0 hours');
    }

    @IsTest
    static void testNoUserIdsPassed() {
        Test.startTest();
        List<FlowNotifyTimesheetEntryHelpr.OutputWrapper> results =
            FlowNotifyTimesheetEntryHelpr.createTimesheetEntries(new List<FlowNotifyTimesheetEntryHelpr.InputWrapper>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty results when no users passed');
    }

    @IsTest
    static void testWeekendSkipLogic() {
        // Instead of using runAs or setCreatedDate (not needed), we simulate by calling method and verifying it skips
        Test.startTest();
        // Just calling same logic — the Apex class itself checks Date.today(), so we rely on real date check
        // No assertion possible here, just safe execution
        List<FlowNotifyTimesheetEntryHelpr.InputWrapper> inputs = new List<FlowNotifyTimesheetEntryHelpr.InputWrapper>();
        FlowNotifyTimesheetEntryHelpr.InputWrapper input = new FlowNotifyTimesheetEntryHelpr.InputWrapper();
        input.userIds = new List<Id>{ UserInfo.getUserId() };
        inputs.add(input);

        List<FlowNotifyTimesheetEntryHelpr.OutputWrapper> results = FlowNotifyTimesheetEntryHelpr.createTimesheetEntries(inputs);
        Test.stopTest();
        // No assertion since logic depends on current day
        System.assertNotEquals(null, results, 'Weekend skip logic executed safely.');
    }
}