public with sharing class TimesheetValidator {
    
    /**
     * Validates that all business days have timesheet entries
     * @param timesheet The timesheet to validate
     * @param entries The entries for this timesheet
     * @return List of validation errors
     */
    public static List<String> validateBusinessDays(Jpeto__Timesheet__c timesheet, List<Jpeto__Timesheet_Entry__c> entries) {
        List<String> errors = new List<String>();
        
        if (timesheet == null) {
            errors.add('Timesheet is required for validation');
            return errors;
        }
        
        if (timesheet.Jpeto__Start_Date__c == null || timesheet.Jpeto__End_Date__c == null) {
            errors.add('Timesheet start and end dates are required');
            return errors;
        }
        
        // Get all business days in the period
        List<Date> businessDays = BusinessDayCalculatorUtil.getBusinessDaysList(
            timesheet.Jpeto__Start_Date__c, 
            timesheet.Jpeto__End_Date__c
        );
        
        if (businessDays.isEmpty()) {
            return errors;
        }
        
        // Get the dates of existing entries
        Set<Date> entryDates = new Set<Date>();
        for (Jpeto__Timesheet_Entry__c entry : entries) {
            if (entry.Jpeto__Date_Worked__c != null) {
                entryDates.add(entry.Jpeto__Date_Worked__c);
            }
        }
        
        // Check for missing business days
        List<Date> missingDays = new List<Date>();
        for (Date businessDay : businessDays) {
            if (!entryDates.contains(businessDay)) {
                missingDays.add(businessDay);
            }
        }
        
        if (!missingDays.isEmpty()) {
            String missingDaysStr = '';
            for (Date missingDay : missingDays) {
                if (missingDaysStr != '') missingDaysStr += ', ';
                missingDaysStr += missingDay.format();
            }
            errors.add('Missing timesheet entries for business days: ' + missingDaysStr);
        }
        
        if (!errors.isEmpty()) {
            // Join with new lines for better readability
            String formattedErrors = '• '+String.join(errors, '\n• ');
            errors.clear();
            errors.add(formattedErrors);
        }
        
        return errors;
    }
    
    /**
     * Validates that zero-hour entries have a reason
     * @param entries The entries to validate
     * @return List of validation errors
     */
    public static List<String> validateZeroHourEntries(List<Jpeto__Timesheet_Entry__c> entries) {
        List<String> errors = new List<String>();
        
        if (entries == null) {
            return errors;
        }
        
        for (Jpeto__Timesheet_Entry__c entry : entries) {
            // Check if hours are zero and reason is not provided
            if (entry.Jpeto__Hours__c != null && entry.Jpeto__Hours__c == 0) {
                if (entry.Jpeto__Type__c == null || entry.Jpeto__Type__c == '' ) {
                    errors.add('Reason is required for zero-hour entries on ' + 
                              (entry.Jpeto__Date_Worked__c != null ? entry.Jpeto__Date_Worked__c.format() : 'Unknown Date'));
                }else if(!(entry.Jpeto__Type__c == 'Sick Leave' || entry.Jpeto__Type__c == 'Bereavement Leave' || entry.Jpeto__Type__c == 'Paid Leave'
                    || entry.Jpeto__Type__c == 'Unpaid Leave'|| entry.Jpeto__Type__c == 'Maternity/Paternity Leave' || entry.Jpeto__Type__c == 'Holiday'
                    || entry.Jpeto__Type__c == 'Floating Holiday' || entry.Jpeto__Type__c == 'No Tasks' || entry.Jpeto__Type__c == 'Other')){
                    //Type must be a valid leave type or no Tasks or Other if Hours is zero
                    errors.add('Valid Reason is required for zero-hour entries on ' + 
                              (entry.Jpeto__Date_Worked__c != null ? entry.Jpeto__Date_Worked__c.format() : 'Unknown Date'));
                }
                // If reason is "Other", additional validation may be needed
                if (entry.Jpeto__Type__c == 'Other' && (entry.Other_Reason__c == null || entry.Other_Reason__c == '')) {
                    errors.add('Additional explanation is required when reason is "Other" for entry on ' + 
                              (entry.Jpeto__Date_Worked__c != null ? entry.Jpeto__Date_Worked__c.format() : 'Unknown Date'));
                }
            }
        }
        
        if (!errors.isEmpty()) {
            // Join with new lines for better readability
            String formattedErrors = '• '+String.join(errors, '\n• ');
            errors.clear();
            errors.add(formattedErrors);
        }
        return errors;
    }
    
    /**
     * Validates that the timesheet has at least one entry
     * @param timesheet The timesheet to validate
     * @param entries The entries for this timesheet
     * @return List of validation errors
     */
    public static List<String> validateHasEntries(Jpeto__Timesheet__c timesheet, List<Jpeto__Timesheet_Entry__c> entries) {
        List<String> errors = new List<String>();
        
        if (timesheet == null) {
            errors.add('Timesheet is required for validation');
            return errors;
        }
        
        if (entries == null || entries.isEmpty()) {
            errors.add('At least one timesheet entry is required before submitting for approval');
        }
        
        if (!errors.isEmpty()) {
            // Join with new lines for better readability
            String formattedErrors = '• '+String.join(errors, '\n• ');
            errors.clear();
            errors.add(formattedErrors);
        }
        
        return errors;
    }
}