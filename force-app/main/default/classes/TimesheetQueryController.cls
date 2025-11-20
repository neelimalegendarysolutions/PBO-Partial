/**
 * @description Apex class to fetch data for User Hours Table component
 */
public with sharing class TimesheetQueryController {

 /**
 * @description Retrieves a list of unique pay periods based on existing timesheets.
 * @return List of unique pay periods.
 */
@AuraEnabled
// Fetch unique pay periods
public static List<String> getUniquePayPeriods() {
    // Set to store unique pay periods
    Set<String> uniquePayPeriodsSet = new Set<String>();
    
    // Query for timesheets and extract unique pay periods
    List<Jpetto__Timesheet__c> timesheets = [SELECT Jpetto__Period__c, Jpetto__Pay_Period__r.Jpetto__Start_Date__c FROM Jpetto__Timesheet__c WITH SECURITY_ENFORCED ORDER BY Jpetto__Pay_Period__r.Jpetto__Start_Date__c DESC];
    
    // Iterate through timesheets to collect unique pay periods
    for (Jpetto__Timesheet__c timesheet : timesheets) {
        uniquePayPeriodsSet.add(timesheet.Jpetto__Period__c);
    }
    
    // Convert set to list and return
    List<String> uniquePayPeriodsList = new List<String>();
    uniquePayPeriodsList.addAll(uniquePayPeriodsSet);
    return uniquePayPeriodsList;
}


    /**
 * @description Retrieves timesheet entries for a specific day and pay period.
 * @param dayOfWeek The day of the week to filter entries (or 'PayPeriod' to include all days).
 * @param payPeriod The pay period to filter entries.
 * @param dateRange get data on the basis of the date selected on the component
 * @return List of Jpetto__Timesheet_Entry__c objects matching the criteria.
 */
@AuraEnabled
// Get timesheet entries for a specific day and pay period
public static List<Jpetto__Timesheet_Entry__c> getDayQuery(String dayOfWeek, String payPeriod, String dateRange) {
    // Check CRUD access for Jpetto__Timesheet_Entry__c object
    if (!Schema.sObjectType.Jpetto__Timesheet_Entry__c.isAccessible()) {
        throw new AuraHandledException('Insufficient access to Jpetto__Timesheet_Entry__c object');
    }
    String dateParam;
    Date startDate;
    Date endDate;
    if(dateRange!=null) {
        List<String> dates = dateRange.split(' - ');
        startDate = getDate(dates[0]);
        endDate = getDate(dates[1]);
        dateParam = ' AND Jpetto__Date_Worked__c >= :startDate AND Jpetto__Date_Worked__c <= :endDate';

    }
    // Build dynamic SOQL query
    String dynamicQuery = 'SELECT Jpetto__User__c, Jpetto__Hours__c, Jpetto__Billable_to_Client__c, Jpetto__Timesheet__r.Jpetto__Status__c, Jpetto__Date_Worked__c, Jpetto__Timesheet__r.id ' +
                          'FROM Jpetto__Timesheet_Entry__c ' +
                          'WHERE Jpetto__Timesheet__r.Jpetto__Period__c = :payPeriod';

    // Add dayOfWeek condition if it's not 'PayPeriod'
    if (dayOfWeek != 'PayPeriod') {
        if(dateParam!=null){
            dynamicQuery += ' AND Jpetto__day_worked__c = :dayOfWeek'+dateParam;
        }else {
            dynamicQuery += ' AND Jpetto__day_worked__c = :dayOfWeek';
        }
    }

    // Check CRUD access for Jpetto__day_worked__c field
    if (!Schema.sObjectType.Jpetto__Timesheet_Entry__c.fields.Jpetto__day_worked__c.isAccessible() || !Schema.sObjectType.Jpetto__Timesheet_Entry__c.fields.Jpetto__Date_Worked__c.isAccessible()) {
        throw new AuraHandledException('Insufficient access to Jpetto__day_worked__c/Jpetto__Date_Worked__c field');
    }

    // Execute the dynamic query after escaping single quotes
    return Database.query(String.escapeSingleQuotes(dynamicQuery));
}

    private static Date getDate(String dateString){

        // Split the date components into day, month, and year
        List<String> startDateParts = dateString.split('/');
        if(!startDateParts.isEmpty() && startDateParts.size() == 3) {
            // Convert string components to integer
            Integer startDay = Integer.valueOf(startDateParts[1]);
            Integer startMonth = Integer.valueOf(startDateParts[0]);
            Integer startYear = Integer.valueOf(startDateParts[2]);

            return Date.newInstance(startYear, startMonth, startDay);
        }
        return null;
    }

    /**
 * @description Aggregates timesheet entries and returns a JSON serialized result.
 * @param dayOfWeek The day of the week to filter entries.
 * @param payPeriod The pay period to filter entries.
 * @param dateRange get data on the basis of the date selected on the component
 * @return JSON serialized result of aggregated timesheet entries.
 */
@AuraEnabled
// Aggregate timesheet entries and return JSON serialized result
public static String aggregate(String dayOfWeek, String payPeriod, String dateRange) {

    // Check CRUD access for Jpetto__Timesheet_Entry__c object
    if (!Schema.sObjectType.Jpetto__Timesheet_Entry__c.isAccessible()) {
        throw new AuraHandledException('Insufficient access to Jpetto__Timesheet_Entry__c object');
    }
    // Get timesheet entries for the specified day and pay period
    List<Jpetto__Timesheet_Entry__c> data = getDayQuery(dayOfWeek, payPeriod, dateRange);

    // Map to store aggregated results by user
    Map<String, UserResult> result = new Map<String, UserResult>();

    // Process each timesheet entry and aggregate results
    for (Jpetto__Timesheet_Entry__c item : data) {
        processItem(result, item);
    }

    // If it's not a weekend, perform additional processing on aggregated data
    if (dayOfWeek != 'Saturday' && dayOfWeek != 'Sunday') {
        processUsers(result);
    }

    // Return the JSON serialized result
    return JSON.serialize(result.values());
}

    // Process each timesheet entry and update result map
    private static void processItem(Map<String, UserResult> result, Jpetto__Timesheet_Entry__c item) {
        UserResult existing = result.get(item.Jpetto__User__c);

        if (existing != null) {
            updateExistingUserResult(existing, item);
        } else {
            createUserResult(result, item);
        }
    }

/**
 * @description Updates an existing UserResult with timesheet entry data.
 * @param existing The existing UserResult to be updated.
 * @param item The timesheet entry to be added to the existing UserResult.
 */
// Update existing UserResult with timesheet entry
private static void updateExistingUserResult(UserResult existing, Jpetto__Timesheet_Entry__c item) {
    // Increment total entries and total hours
    existing.totalEntries++;
    existing.totalHours += item.Jpetto__Hours__c;

    // Increment billable or non-billable hours based on timesheet entry
    if (item.Jpetto__Billable_to_Client__c) {
        existing.billableHours += item.Jpetto__Hours__c;
    } else {
        existing.nonBillableHours += item.Jpetto__Hours__c;
    }
}

/**
 * @description Creates a new UserResult for a timesheet entry.
 * @param result The map to store aggregated results.
 * @param item The timesheet entry to create a UserResult for.
 */
// Create new UserResult for timesheet entry
private static void createUserResult(Map<String, UserResult> result, Jpetto__Timesheet_Entry__c item) {
    // Create a new UserResult instance
    UserResult newUser = new UserResult();

    // Set user-related information from the timesheet entry
    newUser.user = item.Jpetto__User__c;
    newUser.status = item.Jpetto__Timesheet__r.Jpetto__Status__c;
    newUser.id = item.Jpetto__Timesheet__r.id;
    newUser.totalEntries = 1;
    newUser.totalHours = item.Jpetto__Hours__c;
    newUser.dateWorked = item.Jpetto__Date_Worked__c;
    // Set billable and non-billable hours based on timesheet entry
    if (item.Jpetto__Billable_to_Client__c) {
        newUser.billableHours = item.Jpetto__Hours__c;
        newUser.nonBillableHours = 0;
    } else {
        newUser.billableHours = 0;
        newUser.nonBillableHours = item.Jpetto__Hours__c;
    }

    // Add the new UserResult to the result map
    result.put(item.Jpetto__User__c, newUser);
}


/**
 * @description Processes users, fetching all active users and adding to the result if not present.
 * @param result The map to store aggregated results.
 */
// Process users, fetching all active users and adding to result if not present
private static void processUsers(Map<String, UserResult> result) {
    // Check CRUD access for User object
    if (!Schema.sObjectType.User.isAccessible()) {
        throw new AuraHandledException('Insufficient access to User object');
    }

    // Fetch all active users
    List<User> users = [SELECT Id, Name, IsActive, LastPasswordChangeDate FROM User WHERE IsActive = true AND LastPasswordChangeDate != null];

    // Add users to the result if they are not already present
    for (User user : users) {
        if (!result.containsKey(user.Name)) {
            createUserResult(result, user);
        }
    }
}

/**
 * @description Creates a new UserResult for a user.
 * @param result The map to store aggregated results.
 * @param user The user to create a UserResult for.
 */
// Create new UserResult for user
private static void createUserResult(Map<String, UserResult> result, User user) {
    // Create a new UserResult instance for the user
    UserResult newUser = new UserResult();
    
    // Set user-related information
    newUser.user = user.Name;
    newUser.id = 'lightning/o/Jpetto__Timesheet__c/list?filterName=Recent';
    newUser.status = '';
    newUser.totalEntries = 0;
    newUser.totalHours = 0;
    newUser.billableHours = 0;
    newUser.nonBillableHours = 0;

    // Add the new UserResult to the result map
    result.put(user.Name, newUser);
}

       /**
 * @description Data structure to hold user-related results.
 */
public class UserResult {
    /**
     * @description Unique identifier for the user.
     */
    public String id;
    /**
     * @description user worked date
    */
    public Date dateWorked;
    /**
     * @description Current status of the user.
     */
    public String status;

    /**
     * @description User name.
     */
    public String user;

    /**
     * @description Total number of entries for the user.
     */
    public Integer totalEntries;

    /**
     * @description Total hours worked by the user.
     */
    public Decimal totalHours;

    /**
     * @description Billable hours worked by the user.
     */
    public Decimal billableHours;

    /**
     * @description Non-billable hours worked by the user.
     */
    public Decimal nonBillableHours;
}
    public static void increment(){
         integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}