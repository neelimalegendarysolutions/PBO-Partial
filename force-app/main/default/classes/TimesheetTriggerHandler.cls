public with sharing class TimesheetTriggerHandler {
    
    /**
     * Handles before insert and before update operations for timesheets
     * @param timesheets The timesheets being processed
     */
    public static void handleBeforeOperations(List<Jpeto__Timesheet__c> timesheets) {
        // No specific before operations needed for timesheets
        // All validation will happen during submission
    }
    
    /**
     * Handles after insert and after update operations for timesheets
     * @param timesheets The timesheets being processed
     */
    public static void handleAfterOperations(List<Jpeto__Timesheet__c> timesheets) {
        // No specific after operations needed for timesheets
    }
    
    /**
     * Invocable method wrapper to validate timesheet(s) before submission from Flow
     */
    @InvocableMethod(
        label='Validate Timesheet before Submission' 
        description='Validates a timesheet before submission and returns validation errors'
    )
    public static List<FlowResult> validateTimesheetForSubmissionFromFlow(List<FlowInput> inputs) {
        List<FlowResult> results = new List<FlowResult>();
        
        for (FlowInput input : inputs) {
            List<String> errors = validateTimesheetForSubmission(input.timesheetId);
            FlowResult result = new FlowResult();
            result.errorMessages = errors;
            results.add(result);
        }
        
        return results;
    }

    /**
     * Core validation logic - reusable both from Trigger and Flow
     */
    public static List<String> validateTimesheetForSubmission(Id timesheetId) {
        List<String> errors = new List<String>();
        
        if (timesheetId == null) {
            errors.add('Timesheet Id is required for validation.');
            return errors;
        }
        
        // Query the timesheet
        Jpeto__Timesheet__c timesheet = [
            SELECT Id, Name, CreatedDate, Jpeto__Start_Date__c, Jpeto__End_Date__c
            FROM Jpeto__Timesheet__c
            WHERE Id = :timesheetId
            LIMIT 1
        ];
        
        // Get related entries
        List<Jpeto__Timesheet_Entry__c> entries = [
            SELECT Id, Jpeto__Date_Worked__c, Jpeto__Hours__c, Jpeto__Type__c, Other_Reason__c, CreatedDate
            FROM Jpeto__Timesheet_Entry__c 
            WHERE Jpeto__Timesheet__c = :timesheet.Id
            ORDER BY Jpeto__Date_Worked__c
        ];
        
        // Validate that at least one entry exists
        errors.addAll(TimesheetValidator.validateHasEntries(timesheet, entries));
        
        // Validate that all business days have entries
        errors.addAll(TimesheetValidator.validateBusinessDays(timesheet, entries));
        
        // Validate that zero-hour entries have reasons
        errors.addAll(TimesheetValidator.validateZeroHourEntries(entries));
        
        if (!errors.isEmpty()) {
            // Join with new lines for better readability
            String formattedErrors = String.join(errors, '\n• ');
            errors.clear();
            errors.add(formattedErrors);
        }
        return errors;
    }

    /**
     * Inner class to accept Flow input
     */
    public class FlowInput {
        @InvocableVariable(label='Timesheet Id' required=true)
        public Id timesheetId;
    }

    /**
     * Inner class to return Flow output
     */
    public class FlowResult {
        @InvocableVariable(label='Validation Errors')
        public List<String> errorMessages;
    }
}