trigger TimesheetEntry_Trigger on Jpeto__Timesheet_Entry__c (before insert, before update, after insert, after update) {
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            TimesheetEntryTriggerHandler.handleBeforeOperations(
                Trigger.new,
                Trigger.isUpdate ? Trigger.oldMap : null,
                Trigger.isInsert,
                Trigger.isUpdate
            );
        }
    }
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            TimesheetEntryTriggerHandler.handleAfterOperations(Trigger.new);
        }
    }
}