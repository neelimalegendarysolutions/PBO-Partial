@IsTest
private class TimesheetValidatorTest {

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

    @IsTest
    static void testValidateBusinessDays_missingDays() {
        // Mon-Fri period
        Date startD = Date.newInstance(2024,1,1); // Tue
        Date endD   = Date.newInstance(2024,1,5); // Fri
        Jpeto__Timesheet__c ts = makeTimesheet(startD, endD);

        // Provide entries for Tue and Thu only to force missing days
        List<Jpeto__Timesheet_Entry__c> entries = new List<Jpeto__Timesheet_Entry__c>();
        entries.add(new Jpeto__Timesheet_Entry__c(Jpeto__Timesheet__c = ts.Id, Jpeto__Date_Worked__c = Date.newInstance(2024,1,1)));
        entries.add(new Jpeto__Timesheet_Entry__c(Jpeto__Timesheet__c = ts.Id, Jpeto__Date_Worked__c = Date.newInstance(2024,1,3)));

        List<String> errs = TimesheetValidator.validateBusinessDays(ts, entries);
        System.assertEquals(true, !errs.isEmpty(), 'Should find missing business days');
        System.assert(errs[0].contains('Missing timesheet entries for business days'), 'Message should mention missing business days');
    }

    @IsTest
    static void testValidateBusinessDays_noBusinessDaysOrNulls() {
        // Null timesheet
        List<String> errsNullTs = TimesheetValidator.validateBusinessDays(null, new List<Jpeto__Timesheet_Entry__c>());
        System.assertEquals(true, !errsNullTs.isEmpty());
        System.assert(errsNullTs[0].contains('Timesheet is required for validation'));

        // Missing dates on timesheet
        Jpeto__Timesheet__c tsMissing = new Jpeto__Timesheet__c();
        List<String> errsMissingDates = TimesheetValidator.validateBusinessDays(tsMissing, new List<Jpeto__Timesheet_Entry__c>());
        System.assertEquals(true, !errsMissingDates.isEmpty());
        System.assert(errsMissingDates[0].contains('Timesheet start and end dates are required'));

        // Period with no business days (start after end leads to swap in util -> still handles)
        // Here we use weekend only range: Sat-Sun
        Jpeto__Timesheet__c tsWeekend = makeTimesheet(Date.newInstance(2024,1,6), Date.newInstance(2024,1,7));
        List<String> errsWeekend = TimesheetValidator.validateBusinessDays(tsWeekend, new List<Jpeto__Timesheet_Entry__c>());
        // No business days -> no errors expected
        System.assertEquals(true, errsWeekend.isEmpty(), 'No business days => no error');
    }

    @IsTest
    static void testValidateZeroHourEntries_rules() {
        List<Jpeto__Timesheet_Entry__c> entries = new List<Jpeto__Timesheet_Entry__c>();

        // Zero hours without reason
        Jpeto__Timesheet_Entry__c e1 = new Jpeto__Timesheet_Entry__c(Jpeto__Hours__c = 0, Jpeto__Date_Worked__c = Date.newInstance(2024,1,2));
        entries.add(e1);

        // Zero hours with invalid reason
        Jpeto__Timesheet_Entry__c e2 = new Jpeto__Timesheet_Entry__c(Jpeto__Hours__c = 0, Jpeto__Type__c = 'Invalid', Jpeto__Date_Worked__c = Date.newInstance(2024,1,3));
        entries.add(e2);

        // Zero hours with Other but missing additional text
        Jpeto__Timesheet_Entry__c e3 = new Jpeto__Timesheet_Entry__c(Jpeto__Hours__c = 0, Jpeto__Type__c = 'Other', Jpeto__Date_Worked__c = Date.newInstance(2024,1,4));
        entries.add(e3);

        // Valid zero-hours (e.g., Holiday)
        Jpeto__Timesheet_Entry__c e4 = new Jpeto__Timesheet_Entry__c(Jpeto__Hours__c = 0, Jpeto__Type__c = 'Holiday', Jpeto__Date_Worked__c = Date.newInstance(2024,1,5));
        entries.add(e4);

        List<String> errs = TimesheetValidator.validateZeroHourEntries(entries);
        System.assertEquals(true, !errs.isEmpty(), 'Should create errors for invalid zero-hour entries');
        String msg = errs[0];
        System.assertEquals(true, msg.contains('Reason is required for zero-hour entries'), 'Must require a reason');
        System.assertEquals(true, msg.contains('Valid Reason is required for zero-hour entries'), 'Must restrict to valid reasons');
        System.assertEquals(true, msg.contains('Additional explanation is required when reason is "Other"'), 'Other requires extra text');
        // Ensure it didn't flag the valid one
        System.assertEquals(false, msg.contains('2024-01-05'), 'Holiday should be accepted');
    }

    @IsTest
    static void testValidateHasEntries_paths() {
        // Null timesheet
        List<String> errsNull = TimesheetValidator.validateHasEntries(null, new List<Jpeto__Timesheet_Entry__c>());
        System.assertEquals(true, !errsNull.isEmpty());
        System.assert(errsNull[0].contains('Timesheet is required for validation'));

        // No entries
        Jpeto__Timesheet__c ts = makeTimesheet(Date.newInstance(2024,1,1), Date.newInstance(2024,1,7));
        List<String> errsNoEntries = TimesheetValidator.validateHasEntries(ts, new List<Jpeto__Timesheet_Entry__c>());
        System.assertEquals(true, !errsNoEntries.isEmpty());
        System.assert(errsNoEntries[0].contains('At least one timesheet entry is required'));

        // With entries -> no error
        List<Jpeto__Timesheet_Entry__c> entries = new List<Jpeto__Timesheet_Entry__c>{
            new Jpeto__Timesheet_Entry__c(Jpeto__Date_Worked__c = Date.newInstance(2024,1,1), Jpeto__Hours__c = 1)
        };
        List<String> errsOk = TimesheetValidator.validateHasEntries(ts, entries);
        System.assertEquals(true, errsOk.isEmpty(), 'Having entries should pass');
    }
}