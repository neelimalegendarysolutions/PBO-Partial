@IsTest
private class TimesheetEntryTriggerHandlerTest {

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
    static void testBeforeInsert_setsLateFlagsAndHours() {
        Jpeto__Timesheet__c ts = makeTimesheet(Date.newInstance(2024,1,1), Date.newInstance(2024,1,7));

        // Today should not be late in before-insert path
        Jpeto__Timesheet_Entry__c e1 = new Jpeto__Timesheet_Entry__c(
            Jpeto__Timesheet__c = ts.Id,
            Jpeto__Date_Worked__c = Date.today()
        );

        // Far past should be late
        Jpeto__Timesheet_Entry__c e2 = new Jpeto__Timesheet_Entry__c(
            Jpeto__Timesheet__c = ts.Id,
            Jpeto__Date_Worked__c = Date.newInstance(2000,1,1)
        );

        Test.startTest();
        insert new List<Jpeto__Timesheet_Entry__c>{ e1, e2 };
        Test.stopTest();

        // Reload to assert values set in trigger
        List<Jpeto__Timesheet_Entry__c> inserted = [
            SELECT Id, Late_Entry__c, Hours_Late__c, Late_Entry_Datetime__c, Jpeto__Date_Worked__c
            FROM Jpeto__Timesheet_Entry__c
            WHERE Id IN :new List<Id>{ e1.Id, e2.Id }
            ORDER BY Jpeto__Date_Worked__c
        ];
        // First is 2000 entry (earlier date)
        System.assertEquals(true, inserted[0].Late_Entry__c, 'Old date should be late');
        System.assert(inserted[0].Hours_Late__c != null && inserted[0].Hours_Late__c > 36, 'Should have positive hours late');
        System.assertNotEquals(null, inserted[0].Late_Entry_Datetime__c, 'Late datetime should be populated');

        System.assertEquals(false, inserted[1].Late_Entry__c, 'Today should not be late');
        System.assertNotEquals(null, inserted[1].Hours_Late__c, 'Hours Late populated even if zero-ish');
    }

    @IsTest
    static void testBeforeUpdate_recalculatesWhenDateOrHoursChange() {
        Jpeto__Timesheet__c ts = makeTimesheet(Date.newInstance(2024,1,1), Date.newInstance(2024,1,7));

        // Start with a recent date
        Jpeto__Timesheet_Entry__c e = new Jpeto__Timesheet_Entry__c(
            Jpeto__Timesheet__c = ts.Id,
            Jpeto__Date_Worked__c = Date.today(),
            Jpeto__Hours__c = 1
        );
        insert e;

        // Update to far past -> should become late, also change hours to trigger recalc
        e = [SELECT Id, Jpeto__Date_Worked__c, Jpeto__Hours__c FROM Jpeto__Timesheet_Entry__c WHERE Id=:e.Id];
        e.Jpeto__Date_Worked__c = Date.newInstance(2000,1,1);
        e.Jpeto__Hours__c = 2;

        Test.startTest();
        update e;
        Test.stopTest();

        Jpeto__Timesheet_Entry__c afterUpd = [
            SELECT Id, Late_Entry__c, Hours_Late__c, Late_Entry_Datetime__c, Jpeto__Date_Worked__c
            FROM Jpeto__Timesheet_Entry__c
            WHERE Id = :e.Id
        ];
        System.assertEquals(true, afterUpd.Late_Entry__c, 'Should be late after moving to far past');
        System.assert(afterUpd.Hours_Late__c != null && afterUpd.Hours_Late__c > 36);
        System.assertNotEquals(null, afterUpd.Late_Entry_Datetime__c);
    }

    @IsTest
    static void testAfterInsertUpdate_updatesParentAggregates() {
        Jpeto__Timesheet__c ts = makeTimesheet(Date.newInstance(2024,1,1), Date.newInstance(2024,1,7));

        // Create entries: one late, one not late
        Jpeto__Timesheet_Entry__c lateE = new Jpeto__Timesheet_Entry__c(
            Jpeto__Timesheet__c = ts.Id,
            Jpeto__Date_Worked__c = Date.newInstance(2000,1,1)
        );
        Jpeto__Timesheet_Entry__c okE = new Jpeto__Timesheet_Entry__c(
            Jpeto__Timesheet__c = ts.Id,
            Jpeto__Date_Worked__c = Date.today()
        );

        Test.startTest();
        insert new List<Jpeto__Timesheet_Entry__c>{lateE, okE};
        Test.stopTest();

        // After insert, parent should be updated
        ts = [SELECT Id, Total_Late_Entries__c, Total_Hours_Late__c FROM Jpeto__Timesheet__c WHERE Id=:ts.Id];
        System.assertEquals(1, ts.Total_Late_Entries__c, 'One late entry expected');
        System.assert(ts.Total_Hours_Late__c != null && ts.Total_Hours_Late__c > 36, 'Hours late aggregate should be > 36');

        // Now update okE to become late and verify aggregates change
        okE = [SELECT Id, Jpeto__Date_Worked__c FROM Jpeto__Timesheet_Entry__c WHERE Id=:okE.Id];
        okE.Jpeto__Date_Worked__c = Date.newInstance(1999,1,1);

        Test.startTest();
        update okE;
        Test.stopTest();

        ts = [SELECT Id, Total_Late_Entries__c, Total_Hours_Late__c FROM Jpeto__Timesheet__c WHERE Id=:ts.Id];
        System.assertEquals(2, ts.Total_Late_Entries__c, 'Two late entries expected after update');
        System.assert(ts.Total_Hours_Late__c > 72, 'Hours late aggregate should grow');
    }

    @IsTest
    static void testBulkBehavior_noDmlLimitIssues() {
        Jpeto__Timesheet__c ts = makeTimesheet(Date.newInstance(2024,1,1), Date.newInstance(2024,1,7));

        List<Jpeto__Timesheet_Entry__c> rows = new List<Jpeto__Timesheet_Entry__c>();
        for (Integer i=0; i<50; i++) {
            // Apex does not support the % operator; use Math.mod for modulo
            Date d = (Math.mod(i, 2) == 0) ? Date.newInstance(2000,1,1) : Date.today();
            rows.add(new Jpeto__Timesheet_Entry__c(Jpeto__Timesheet__c=ts.Id, Jpeto__Date_Worked__c=d, Jpeto__Hours__c=1));
        }

        Test.startTest();
        insert rows;
        Test.stopTest();

        // Ensure no exceptions and aggregates computed
        ts = [SELECT Id, Total_Late_Entries__c, Total_Hours_Late__c FROM Jpeto__Timesheet__c WHERE Id=:ts.Id];
        System.assert(ts.Total_Late_Entries__c != null && ts.Total_Late_Entries__c >= 25, 'About half late depending on parity choice');
        System.assert(ts.Total_Hours_Late__c != null && ts.Total_Hours_Late__c > 0);
    }
}