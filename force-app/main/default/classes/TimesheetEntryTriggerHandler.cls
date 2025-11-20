public with sharing class TimesheetEntryTriggerHandler {
    
    /**
     * Handles before insert and before update operations for timesheet entries
     * @param entries The entries being processed
     */
    public static void handleBeforeOperations(
        List<Jpeto__Timesheet_Entry__c> newEntries,
        Map<Id, Jpeto__Timesheet_Entry__c> oldEntryMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (newEntries == null || newEntries.isEmpty()) return;
        
        // Collect parent timesheet IDs
        Set<Id> timesheetIds = new Set<Id>();
        for (Jpeto__Timesheet_Entry__c entry : newEntries) {
            if (entry.Jpeto__Timesheet__c != null) timesheetIds.add(entry.Jpeto__Timesheet__c);
        }
        
        // Query parent timesheets
        Map<Id, Jpeto__Timesheet__c> timesheetMap = new Map<Id, Jpeto__Timesheet__c>();
        if (!timesheetIds.isEmpty()) {
            List<Jpeto__Timesheet__c> timesheets = [
                SELECT Id, Jpeto__Start_Date__c, Jpeto__End_Date__c 
                FROM Jpeto__Timesheet__c 
                WHERE Id IN :timesheetIds
            ];
            for (Jpeto__Timesheet__c ts : timesheets) {
                timesheetMap.put(ts.Id, ts);
            }
        }
        
        // Process each entry
        for (Jpeto__Timesheet_Entry__c entry : newEntries) {
            Boolean recalc = isInsert || (isUpdate && oldEntryMap != null && (
                entry.Jpeto__Date_Worked__c != oldEntryMap.get(entry.Id).Jpeto__Date_Worked__c ||
                entry.Jpeto__Hours__c != oldEntryMap.get(entry.Id).Jpeto__Hours__c
            ));
            if (!recalc) continue;
            
            Jpeto__Timesheet__c timesheet = timesheetMap.get(entry.Jpeto__Timesheet__c);
            if (timesheet != null) {
                entry.Late_Entry__c = BusinessDayCalculatorUtil.isEntryLate(entry, timesheet);
                entry.Hours_Late__c = BusinessDayCalculatorUtil.getHoursLate(entry, timesheet);
                if(entry.Late_Entry__c){
                    entry.Late_Entry_Datetime__c = System.now();
                }
            }
        }
    }

    
    /**
     * Handles after insert and after update operations for timesheet entries
     * @param entries The entries being processed
     */
    public static void handleAfterOperations(List<Jpeto__Timesheet_Entry__c> entries) {
        if (entries == null || entries.isEmpty()) {
            return;
        }
        
        // Get the parent timesheet IDs
        Set<Id> timesheetIds = new Set<Id>();
        for (Jpeto__Timesheet_Entry__c entry : entries) {
            if (entry.Jpeto__Timesheet__c != null) {
                timesheetIds.add(entry.Jpeto__Timesheet__c);
            }
        }
        
        // Query the parent timesheets
        Map<Id, Jpeto__Timesheet__c> timesheetMap = new Map<Id, Jpeto__Timesheet__c>();
        if (!timesheetIds.isEmpty()) {
            List<Jpeto__Timesheet__c> timesheets = [
                SELECT Id, Jpeto__Start_Date__c, Jpeto__End_Date__c 
                FROM Jpeto__Timesheet__c 
                WHERE Id IN :timesheetIds
            ];
            for (Jpeto__Timesheet__c ts : timesheets) {
                timesheetMap.put(ts.Id, ts);
            }
        }
        
        // Update the parent timesheet with late entry counts
        updateTimesheetLateEntryCounts(timesheetIds, timesheetMap);
    }
    
    /**
     * Updates the late entry counts on parent timesheets
     * @param timesheetIds The IDs of timesheets to update
     * @param timesheetMap Map of timesheet IDs to timesheet records
     */
    private static void updateTimesheetLateEntryCounts(Set<Id> timesheetIds, Map<Id, Jpeto__Timesheet__c> timesheetMap) {
        if (timesheetIds.isEmpty()) {
            return;
        }
        
        // Query for late entries for these timesheets
        List<AggregateResult> lateEntryResults = [
            SELECT Jpeto__Timesheet__c, COUNT(Id) totalLateEntries, SUM(Hours_Late__c) totalHoursLate
            FROM Jpeto__Timesheet_Entry__c 
            WHERE Jpeto__Timesheet__c IN :timesheetIds AND Late_Entry__c = true
            GROUP BY Jpeto__Timesheet__c
        ];
        
        // Prepare updates
        List<Jpeto__Timesheet__c> timesheetsToUpdate = new List<Jpeto__Timesheet__c>();
        
        Map<Id, AggregateResult> lateEntryMap = new Map<Id, AggregateResult>();
        for (AggregateResult ar : lateEntryResults) {
            lateEntryMap.put((Id)ar.get('Jpeto__Timesheet__c'), ar);
        }
        
        // Update each timesheet
        for (Id timesheetId : timesheetIds) {
            Jpeto__Timesheet__c timesheet = timesheetMap.get(timesheetId);
            if (timesheet != null) {
                AggregateResult ar = lateEntryMap.get(timesheetId);
                if (ar != null) {
                    timesheet.Total_Late_Entries__c = (Integer)ar.get('totalLateEntries');
                    timesheet.Total_Hours_Late__c = (Decimal)ar.get('totalHoursLate');
                } else {
                    timesheet.Total_Late_Entries__c = 0;
                    timesheet.Total_Hours_Late__c = 0;
                }
                timesheetsToUpdate.add(timesheet);
            }
        }
        
        // Perform bulk update
        if (!timesheetsToUpdate.isEmpty()) {
            update timesheetsToUpdate;
        }
    }
}