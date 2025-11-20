public with sharing class BusinessDayCalculatorUtil {

    // Helper: returns 1 = Sunday, 2 = Monday, ... , 7 = Saturday
    private static Integer getDayOfWeek(Date d) {
        if (d == null) return null;
        // Reference date: 1900-01-07 is a Sunday.
        Date ref = Date.newInstance(1900, 1, 7);
        Integer days = ref.daysBetween(d);
        // compute days mod 7 without using the % operator
        Integer weeksPart = days / 7;
        Integer offset = days - (weeksPart * 7);
        if (offset < 0) {
            offset += 7;
        }
        return offset + 1;
    }

    /**
     * Calculates the number of business days between two dates (inclusive)
     */
    public static Integer getBusinessDaysBetweenDates(Date startDate, Date endDate) {
        if (startDate == null || endDate == null) {
            return 0;
        }

        // Ensure startDate is before or equal to endDate
        if (startDate > endDate) {
            Date temp = startDate;
            startDate = endDate;
            endDate = temp;
        }

        Integer businessDays = 0;
        Date currentDate = startDate;

        while (currentDate <= endDate) {
            // Apex mapping: 1 = Sunday ... 7 = Saturday
            Integer dayOfWeek = getDayOfWeek(currentDate);
            if (dayOfWeek >= 2 && dayOfWeek <= 6) { // Monday–Friday
                businessDays++;
            }
            currentDate = currentDate.addDays(1);
        }

        return businessDays;
    }

    /**
     * Gets all business days between two dates (inclusive)
     */
    public static List<Date> getBusinessDaysList(Date startDate, Date endDate) {
        List<Date> businessDays = new List<Date>();

        if (startDate == null || endDate == null) {
            return businessDays;
        }

        // Ensure startDate is before or equal to endDate
        if (startDate > endDate) {
            Date temp = startDate;
            startDate = endDate;
            endDate = temp;
        }

        Date currentDate = startDate;

        while (currentDate <= endDate) {
            Integer dayOfWeek = getDayOfWeek(currentDate);
            if (dayOfWeek >= 2 && dayOfWeek <= 6) { // Monday–Friday
                businessDays.add(currentDate);
            }
            currentDate = currentDate.addDays(1);
        }

        return businessDays;
    }

    /**
     * Calculates if a timesheet entry is late (submitted more than 36 hours after the DateWorked)
     */
    public static Boolean isEntryLate(Jpeto__Timesheet_Entry__c entry, Jpeto__Timesheet__c timesheet) {
        if (entry == null || entry.Jpeto__Date_Worked__c == null) {
            return false;
        }

        // Determine the reference time
        DateTime referenceTime;
        if (entry.Id == null) { // before insert
            referenceTime = DateTime.now();
        } else { // update
            referenceTime = entry.CreatedDate != null ? entry.CreatedDate : DateTime.now();
        }
    
        // Convert DateWorked to DateTime at midnight and add 36 hours
        DateTime deadline = DateTime.newInstance(entry.Jpeto__Date_Worked__c, Time.newInstance(0,0,0,0)).addHours(36);
        return referenceTime > deadline;
    }

    /**
     * Calculates how many hours late an entry is
     */
    public static Decimal getHoursLate(Jpeto__Timesheet_Entry__c entry, Jpeto__Timesheet__c timesheet) {
        if (entry == null || entry.Jpeto__Date_Worked__c == null) {
            return 0;
        }

        DateTime referenceTime;
        if (entry.Id == null) { // before insert
            referenceTime = DateTime.now();
        } else { // update
            referenceTime = entry.CreatedDate != null ? entry.CreatedDate : DateTime.now();
        }
    
        DateTime deadline = DateTime.newInstance(entry.Jpeto__Date_Worked__c, Time.newInstance(0,0,0,0)).addHours(36);
        Long diffMillis = referenceTime.getTime() - deadline.getTime();
        // Convert milliseconds to hours as Decimal
        Decimal diffHours = Decimal.valueOf(diffMillis) / 3600000;
    
        return diffHours > 0 ? diffHours : 0;
    }
}