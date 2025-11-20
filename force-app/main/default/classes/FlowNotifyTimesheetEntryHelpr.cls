public class FlowNotifyTimesheetEntryHelpr {
    
    // ===== INPUT STRUCTURE =====
    public class InputWrapper {
        @InvocableVariable(required=true description='List of User Ids for whom to create Timesheet Entry')
       // public List<String> userIds;
		public List<Id> userIds;
    }

    // ===== OUTPUT STRUCTURE =====
    public class OutputWrapper {
        @InvocableVariable(description='Created Timesheet Entry Id')
        public Id timesheetEntryId;
        
        @InvocableVariable(description='User Id for whom the entry was created')
        public Id userId;
    }

    // ===== MAIN INVOCABLE METHOD =====
    @InvocableMethod(label='Create Timesheet Entry and Notify Users' 
                     description='Fetches Work Items, Timesheets, creates Timesheet Entries, and sends email notifications for multiple users.')
    public static List<OutputWrapper> createTimesheetEntries(List<InputWrapper> requests) {
        
        	// Skip execution on weekends
            Date todayDate = Date.today();
            Integer dayOfWeek = todayDate.toStartOfWeek().daysBetween(todayDate);         	
            // 0 = Sunday, 6 = Saturday
            if (dayOfWeek == 0 || dayOfWeek == 6) {               
                return new List<OutputWrapper>();
            }

        List<OutputWrapper> results = new List<OutputWrapper>();
        Set<Id> allUserIds = new Set<Id>();

        // Collect all User Ids from all Flow inputs
        for (InputWrapper req : requests) {
            if (req != null && req.userIds != null) {
                allUserIds.addAll(req.userIds);
            }
        }        
        

        if (allUserIds.isEmpty()) {            
            return results;
        }
            

        // ------------------------------
        // 1️ Fetch Work Items per User
        // ------------------------------
        Map<Id, Jpeto__Work_Item__c> userWorkItemMap = new Map<Id, Jpeto__Work_Item__c>();
        List<Jpeto__Work_Item__c> workItemList = [SELECT Id, Name,  Jpeto__Assigned_User__c FROM Jpeto__Work_Item__c 
            WHERE Jpeto__Assigned_User__c IN :allUserIds            
            ORDER BY LastModifiedDate  DESC
        ];       

        for (Jpeto__Work_Item__c wi : workItemList) {
            if (!userWorkItemMap.containsKey(wi.Jpeto__Assigned_User__c)) {
                userWorkItemMap.put(wi.Jpeto__Assigned_User__c, wi);
            }
        }        

        // ------------------------------
        // 2️ Fetch Timesheets per User
        // ------------------------------
        Map<Id, Jpeto__Timesheet__c> userTimesheetMap = new Map<Id, Jpeto__Timesheet__c>();
        List<Jpeto__Timesheet__c> timesheetList = [
            SELECT Id, Jpeto__User_Id__c
            FROM Jpeto__Timesheet__c
            WHERE Jpeto__User__c  IN :allUserIds
            ORDER BY CreatedDate DESC
        ];        

        for (Jpeto__Timesheet__c ts : timesheetList) {
            if (!userTimesheetMap.containsKey(ts.Jpeto__User_Id__c)) {
                userTimesheetMap.put(ts.Jpeto__User_Id__c, ts);
            }
        }
        
		
        //RecordTypeId
        Id missRecordTypeId;
        List<RecordType> recordTypes = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Jpeto__Timesheet_Entry__c' 
            AND DeveloperName = 'Missed_Entry'
            LIMIT 1
        ];
        if (!recordTypes.isEmpty()) missRecordTypeId = recordTypes[0].Id;
        
        

        // ------------------------------
        // 3️ Create Timesheet Entries in Bulk
        // ------------------------------
        List<Jpeto__Timesheet_Entry__c> tseList = new List<Jpeto__Timesheet_Entry__c>();
        Map<Id, Id> userToTseIdMap = new Map<Id, Id>();
        Date prevWorkDate;
        
        if (dayOfWeek == 1) { // Monday
            prevWorkDate =todayDate.addDays(-3);  // Go back to Friday
            
        } else {
            prevWorkDate = todayDate.addDays(-1); // Go back to yesterday
            
        }

        for (Id uid : allUserIds) {
            if (!userTimesheetMap.containsKey(uid)) {               
                continue;
            }

            Jpeto__Work_Item__c wi = userWorkItemMap.get(uid);
            Jpeto__Timesheet__c ts = userTimesheetMap.get(uid);

            Jpeto__Timesheet_Entry__c tse = new Jpeto__Timesheet_Entry__c(
                Jpeto__Timesheet__c = ts.Id,
                Jpeto__Work_Item__c = (wi == null ? null : wi.Id),
                Jpeto__Date_Worked__c = prevWorkDate,
                Jpeto__Hours__c = 0,
                Jpeto__Description__c = 'Reason: ',
                Jpeto__Type__c = 'Auto Created',
                RecordTypeId = missRecordTypeId
            );
            tseList.add(tse);

            System.debug(' Prepared Timesheet Entry for user: ' + uid + 
                         ', WorkItem: ' + (wi != null ? wi.Id : 'None') + 
                         ', Timesheet: ' + ts.Id);
        }

        if (!tseList.isEmpty()) {
            insert tseList;
            
        } else {
            System.debug('️ No Timesheet Entries to insert.');
        }

        // Map inserted TSEs back to users (based on order)
        Integer i = 0;
        for (Id uid : allUserIds) {
            if (i < tseList.size()) {
                userToTseIdMap.put(uid, tseList[i].Id);
                i++;
            }
        }
        System.debug(' User-to-TimesheetEntry Map: ' + userToTseIdMap);

        // ------------------------------
        // ️4 Send Email Notifications (in Bulk)
        // ------------------------------
        
        sendTimesheetEntryEmails(userToTseIdMap);        

        // ------------------------------
        // 5️ Prepare Output for Flow
        // ------------------------------
        for (Id uid : userToTseIdMap.keySet()) {
            OutputWrapper out = new OutputWrapper();
            out.userId = uid;
            out.timesheetEntryId = userToTseIdMap.get(uid);
            results.add(out);
        }
       
        return results;
    }

    // ===== HELPER: Send Bulk Emails =====
    private static void sendTimesheetEntryEmails(Map<Id, Id> userToTseIdMap) {
        if (userToTseIdMap.isEmpty()) {            
            return;
        }       

        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Email, Name,Manager.Email  FROM User WHERE Id IN :userToTseIdMap.keySet()
        ]);

        Map<Id, Jpeto__Timesheet_Entry__c> tseMap = new Map<Id, Jpeto__Timesheet_Entry__c>([
            SELECT Id, Name, Jpeto__Date_Worked__c, Jpeto__Hours__c
            FROM Jpeto__Timesheet_Entry__c
            WHERE Id IN :userToTseIdMap.values()
        ]);        

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
		Id templateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Timesheet_Entry_Missing_Template' LIMIT 1].Id;

        for (Id uid : userToTseIdMap.keySet()) {
            User u = userMap.get(uid);
            Jpeto__Timesheet_Entry__c tse = tseMap.get(userToTseIdMap.get(uid));

            if (u == null || String.isBlank(u.Email)) {                
                continue;
            }
           
            // Fetch the email template ID dynamically by DeveloperName (recommended best practice)
                        
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTemplateId(templateId);
            email.setTargetObjectId(u.Id);             // Required when using templates with merge fields
            email.setWhatId(userToTseIdMap.get(uid));  // Optional: link to Timesheet Entry record if template uses it
            email.setSaveAsActivity(false);
            
            if(string.isnotBlank(u.Manager.Email)){
                email.setCcAddresses(new list<string>{u.Manager.Email});
            }
            emails.add(email);
            
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
            
        } else {
            System.debug(' No emails were sent — no valid users or records.');
        }
    }
}