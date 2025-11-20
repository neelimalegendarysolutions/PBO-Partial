@IsTest
private class TimesheetTriggerHandlerTest {

    private static Jpeto__Timesheet__c makeTimesheet(Date startD, Date endD) {        
        Jpeto__Pay_Period__c payPeriod = [SELECT Id FROM Jpeto__Pay_Period__c 
                                          WHERE Jpeto__Start_Date__c = :startD AND 
                                         Jpeto__End_Date__c = :endD LIMIT 1];
        if(payPeriod != null){
            Jpeto__Timesheet__c ts = new Jpeto__Timesheet__c(Jpeto__Pay_Period__c = payPeriod.Id);
        	insert ts;
            return ts;
        }else{
            Jpeto__Pay_Period__c newPayPeriod = new Jpeto__Pay_Period__c(Jpeto__Start_Date__c = startD, 
                                                                  Jpeto__End_Date__c = endD);
            insert newPayPeriod;
            Jpeto__Timesheet__c ts = new Jpeto__Timesheet__c(Jpeto__Pay_Period__c = newPayPeriod.Id);
            insert ts;
            return ts;
        }
    }

    private static Jpeto__Timesheet_Entry__c makeEntry(Id timesheetId, Date d, Decimal hrs, String typeVal, String otherReason) {
        Jpeto__Timesheet_Entry__c e = new Jpeto__Timesheet_Entry__c(
            Jpeto__Timesheet__c = timesheetId,
            Jpeto__Date_Worked__c = d,
            Jpeto__Hours__c = hrs,
            Jpeto__Type__c = typeVal
        );
        e.Other_Reason__c = otherReason;
        return e;
    }

    @IsTest
    static void testValidateTimesheetForSubmission_errorsAggregated() {
        // Timesheet for a Mon-Fri period
        Date startD = Date.newInstance(2024,1,1); // Tue
        Date endD   = Date.newInstance(2024,1,5); // Fri
        Jpeto__Timesheet__c ts = makeTimesheet(startD, endD);

        // Insert entries with intentional gaps and issues:
        // - Missing some business days
        // - One zero-hour without valid reason
        // - One zero-hour 'Other' without other text
        List<Jpeto__Timesheet_Entry__c> ins = new List<Jpeto__Timesheet_Entry__c>{
            makeEntry(ts.Id, Date.newInstance(2024,1,1), 1, null, null),                 // Tue with 1 hr
            makeEntry(ts.Id, Date.newInstance(2024,1,2), 0, null, null),                 // Wed zero hr no reason -> error
            makeEntry(ts.Id, Date.newInstance(2024,1,3), 0, 'Other', null)               // Thu zero hr Other but no text -> error
            // Missing Fri intentionally
        };
        insert ins;

        Test.startTest();
        List<String> errors = TimesheetTriggerHandler.validateTimesheetForSubmission(ts.Id);
        Test.stopTest();

        System.assertEquals(true, !errors.isEmpty(), 'Should return validation errors');
        String msg = errors[0];
        System.assertEquals(true, msg.contains('At least one timesheet entry is required') == false, 'We do have entries');
        System.assertEquals(true, msg.contains('Missing timesheet entries for business days'), 'Should include missing business days');
        System.assertEquals(true, msg.contains('Reason is required for zero-hour entries'), 'Zero hours without reason flagged');
        System.assertEquals(true, msg.contains('Additional explanation is required when reason is "Other"'), 'Other requires text');
    }

    @IsTest
    static void testValidateTimesheetForSubmission_okScenario() {
        // Full Mon-Fri with valid reasons for any zero-hour entries
        Date startD = Date.newInstance(2024,1,1); // Tue
        Date endD   = Date.newInstance(2024,1,5); // Fri
        Jpeto__Timesheet__c ts = makeTimesheet(startD, endD);

        List<Jpeto__Timesheet_Entry__c> ins = new List<Jpeto__Timesheet_Entry__c>{
            makeEntry(ts.Id, Date.newInstance(2024,1,1), 1, null, null),
            makeEntry(ts.Id, Date.newInstance(2024,1,2), 2, null, null),
            makeEntry(ts.Id, Date.newInstance(2024,1,3), 0, 'Holiday', null), // allowed zero-hour reason
            makeEntry(ts.Id, Date.newInstance(2024,1,4), 3, null, null),
            makeEntry(ts.Id, Date.newInstance(2024,1,5), 4, null, null)
        };
        insert ins;

        Test.startTest();
        List<String> errors = TimesheetTriggerHandler.validateTimesheetForSubmission(ts.Id);
        Test.stopTest();

        System.assertEquals(true, errors.isEmpty(), 'All validations should pass');
    }

    @IsTest
    static void testInvocableWrapper_singleInput() {
        Date startD = Date.newInstance(2024,1,1);
        Date endD   = Date.newInstance(2024,1,5);
        Jpeto__Timesheet__c ts = makeTimesheet(startD, endD);

        // Make it valid to get empty errors
        insert new List<Jpeto__Timesheet_Entry__c>{
            makeEntry(ts.Id, Date.newInstance(2024,1,1), 1, null, null),
            makeEntry(ts.Id, Date.newInstance(2024,1,2), 1, null, null),
            makeEntry(ts.Id, Date.newInstance(2024,1,3), 1, null, null),
            makeEntry(ts.Id, Date.newInstance(2024,1,4), 1, null, null),
            makeEntry(ts.Id, Date.newInstance(2024,1,5), 1, null, null)
        };

        TimesheetTriggerHandler.FlowInput fi = new TimesheetTriggerHandler.FlowInput();
        fi.timesheetId = ts.Id;

        Test.startTest();
        List<TimesheetTriggerHandler.FlowResult> out = TimesheetTriggerHandler.validateTimesheetForSubmissionFromFlow(new List<TimesheetTriggerHandler.FlowInput>{ fi });
        Test.stopTest();

        System.assertEquals(1, out.size());
        System.assertEquals(true, out[0].errorMessages.isEmpty(), 'No errors expected for valid timesheet');
    }

    @IsTest
    static void testValidateTimesheetForSubmission_nullGuard() {
        Test.startTest();
        List<String> errs = TimesheetTriggerHandler.validateTimesheetForSubmission(null);
        Test.stopTest();
        System.assertEquals(true, !errs.isEmpty());
        System.assertEquals(true, errs[0].contains('Timesheet Id is required'), 'Null guard should trigger');
    }
}