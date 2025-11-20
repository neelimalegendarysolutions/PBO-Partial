@IsTest
private class BusinessDayCalculatorUtilTest {

    @IsTest
    static void testGetBusinessDaysBetweenDates_basicRanges() {
        // Mon 2024-01-01 to Fri 2024-01-05 (5 business days)
        Date startD = Date.newInstance(2024, 1, 1);
        Date endD = Date.newInstance(2024, 1, 5);
        System.assertEquals(5, BusinessDayCalculatorUtil.getBusinessDaysBetweenDates(startD, endD), 'Mon-Fri should be 5');

        // Include weekend: Fri to next Mon should be 2 business days (Fri and Mon)
        Date fri = Date.newInstance(2024, 1, 5);
        Date mon = Date.newInstance(2024, 1, 8);
        System.assertEquals(2, BusinessDayCalculatorUtil.getBusinessDaysBetweenDates(fri, mon), 'Fri + Mon = 2');

        // Same day on weekend: Saturday -> 0
        Date sat = Date.newInstance(2024, 1, 6);
        System.assertEquals(0, BusinessDayCalculatorUtil.getBusinessDaysBetweenDates(sat, sat), 'Saturday is not business day');

        // Same day weekday: Tuesday -> 1
        Date tue = Date.newInstance(2024, 1, 2);
        System.assertEquals(1, BusinessDayCalculatorUtil.getBusinessDaysBetweenDates(tue, tue), 'Weekday same day = 1');

        // Reversed order: end before start -> function should swap
        System.assertEquals(5, BusinessDayCalculatorUtil.getBusinessDaysBetweenDates(endD, startD), 'Reversed dates still 5');
    }

    @IsTest
    static void testGetBusinessDaysList_inclusiveAndOrder() {
        // Range spanning weekend; ensure only Mon-Fri returned
        Date startD = Date.newInstance(2024, 1, 4); // Thu
        Date endD = Date.newInstance(2024, 1, 9);   // Tue
        List<Date> biz = BusinessDayCalculatorUtil.getBusinessDaysList(startD, endD);
        System.assertEquals(4, biz.size(), 'Thu, Fri, Mon, Tue = 4');
        System.assertEquals(Date.newInstance(2024,1,4), biz[0]);
        System.assertEquals(Date.newInstance(2024,1,5), biz[1]);
        System.assertEquals(Date.newInstance(2024,1,8), biz[2]);
        System.assertEquals(Date.newInstance(2024,1,9), biz[3]);

        // Null handling
        System.assertEquals(0, BusinessDayCalculatorUtil.getBusinessDaysList(null, endD).size());
        System.assertEquals(0, BusinessDayCalculatorUtil.getBusinessDaysList(startD, null).size());
    }

    @IsTest
    static void testIsEntryLate_beforeInsert_andUpdatePaths() {
        // Build minimal parent Timesheet (dates not used directly by isEntryLate but pass type)
        Jpeto__Pay_Period__c payPeriod = new Jpeto__Pay_Period__c(Jpeto__Start_Date__c = Date.today().toStartOfMonth(), 
                                                                  Jpeto__End_Date__c = Date.today().toStartOfMonth().addDays(15));
        insert payPeriod;
        Jpeto__Timesheet__c ts = new Jpeto__Timesheet__c(Jpeto__Pay_Period__c = payPeriod.Id);
        insert ts;

        // Case 1: Before insert path (Id==null) - entry not late if within 36h of DateWorked = now
        Jpeto__Timesheet_Entry__c e1 = new Jpeto__Timesheet_Entry__c(
            Jpeto__Timesheet__c = ts.Id,
            Jpeto__Date_Worked__c = Date.today()
        );
        // We cannot directly set CreatedDate before insert; method uses DateTime.now() in before-insert path
        Boolean late1 = BusinessDayCalculatorUtil.isEntryLate(e1, ts);
        // If run any time before +36h, this should be false
        System.assertEquals(false, late1, 'Entry for today should not be late within 36h');

        // Case 2: Update path (Id!=null) - CreatedDate considered if available
        // Create a persisted entry with yesterday as Date_Worked__c and ensure current time is > 36h since midnight yesterday
        // This is generally true when test runs at least on next day afternoon; to avoid time dependency, use a much older date.
        Jpeto__Timesheet_Entry__c e2 = new Jpeto__Timesheet_Entry__c(
            Jpeto__Timesheet__c = ts.Id,
            Jpeto__Date_Worked__c = Date.newInstance(2000,1,1) // far in the past
        );
        insert e2;

        // Reload to get CreatedDate populated
        e2 = [SELECT Id, CreatedDate, Jpeto__Timesheet__c, Jpeto__Date_Worked__c FROM Jpeto__Timesheet_Entry__c WHERE Id = :e2.Id];
        Boolean late2 = BusinessDayCalculatorUtil.isEntryLate(e2, ts);
        System.assertEquals(true, late2, 'Very old DateWorked should be considered late on update path');
    }

    @IsTest
    static void testGetHoursLate_calculationAndFloorAtZero() {
        Jpeto__Pay_Period__c payPeriod = new Jpeto__Pay_Period__c(Jpeto__Start_Date__c = Date.today().toStartOfMonth(), 
                                                                  Jpeto__End_Date__c = Date.today().toStartOfMonth().addDays(15));
        insert payPeriod;
        Jpeto__Timesheet__c ts = new Jpeto__Timesheet__c(Jpeto__Pay_Period__c = payPeriod.Id);
        insert ts;

        // Before insert path -> uses now as reference; for today dateworked, should be ~0 hours late
        Jpeto__Timesheet_Entry__c e1 = new Jpeto__Timesheet_Entry__c(Jpeto__Timesheet__c=ts.Id, Jpeto__Date_Worked__c=Date.today());
        Decimal h1 = BusinessDayCalculatorUtil.getHoursLate(e1, ts);
        System.assertEquals(true, h1 >= 0, 'hours late is non-negative');
        System.assertEquals(true, h1 < 36, 'for today, should be less than 36 hours late');

        // Update path with very old date -> large positive hours late
        Jpeto__Timesheet_Entry__c e2 = new Jpeto__Timesheet_Entry__c(Jpeto__Timesheet__c=ts.Id, Jpeto__Date_Worked__c=Date.newInstance(2000,1,1));
        insert e2;
        e2 = [SELECT Id, CreatedDate, Jpeto__Timesheet__c, Jpeto__Date_Worked__c FROM Jpeto__Timesheet_Entry__c WHERE Id = :e2.Id];
        Decimal h2 = BusinessDayCalculatorUtil.getHoursLate(e2, ts);
        System.assertEquals(true, h2 > 36, 'far past should give many hours late');

        // Null guards
        System.assertEquals(0, BusinessDayCalculatorUtil.getHoursLate(null, ts));
        System.assertEquals(0, BusinessDayCalculatorUtil.getHoursLate(new Jpeto__Timesheet_Entry__c(), ts));
    }
}