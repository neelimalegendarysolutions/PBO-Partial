public with sharing class WorkItemControllerPMT {
    public class FieldMetadata {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public FieldMetadata(String label, String apiName) {
            this.label = label;
            this.value = apiName;
        }
    }
    
    public class SprintWorkItemCount {
        @AuraEnabled public String sprintId;
        @AuraEnabled public Integer count;
        
        public SprintWorkItemCount(String sprintId, Integer count) {
            this.sprintId = sprintId;
            this.count = count;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWorkItems(
        String projectId, 
        String sprintId, 
        String recordTypeId, 
        Boolean isMasterRecordTypeId, 
        String userId,
        Long refreshTrigger
    ) {
        Map<String, Object> response = new Map<String, Object>();
        List<Map<String, Object>> resultList = new List<Map<String, Object>>();
        List<FieldMetadata> fieldMetadataList = new List<FieldMetadata>();
        
        try {
            String objectName = 'Jpeto__Work_Item__c';
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult describeResult = targetType.getDescribe();
            Schema.FieldSet fieldSet = describeResult.fieldSets.getMap().get('DefaultWorkItemFieldSet');
            
            // Always include "All" filter
            fieldMetadataList.add(new FieldMetadata('All', 'All'));
            
            String queryString = 'SELECT Id';
            Boolean sprintFieldPresent = false;
            
            // Build query from field set
            for (Schema.FieldSetMember f : fieldSet.getFields()) {
                String apiName = f.getFieldPath();
                queryString += ', ' + apiName;
                fieldMetadataList.add(new FieldMetadata(f.getLabel(), f.getLabel()));
                
                if (f.getType() == Schema.DisplayType.REFERENCE) {
                    queryString += addReferenceFieldToQuery(targetType, apiName);
                }
                
                if (apiName == 'Jpeto__Sprint__c') {
                    sprintFieldPresent = true;
                }
            }
            
            // Ensure Sprint always included
            if (!sprintFieldPresent) {
                queryString += ', Jpeto__Sprint__c, Jpeto__Sprint__r.Name';
            }
            
            // WHERE conditions
            queryString += ' FROM ' + objectName + ' WHERE Jpeto__Project__c = :projectId';
            if (String.isNotBlank(sprintId)) {
                queryString += ' AND (Jpeto__Sprint__c = :sprintId OR Jpeto__Sprint__c = null)';
            }
            if (!isMasterRecordTypeId) {
                queryString += ' AND RecordTypeId = :recordTypeId';
            }
            if (userId != null) {
                queryString += ' AND Jpeto__Assigned_User__c = :userId';
            }
            
            // Execute query
            List<SObject> records = Database.query(queryString);
            
            // Build rows
            for (SObject record : records) {
                Map<String, Object> row = new Map<String, Object>();
                row.put('Id', record.get('Id'));
                
                for (Schema.FieldSetMember f : fieldSet.getFields()) {
                    String apiName = f.getFieldPath();
                    String label = f.getLabel();
                    if (f.getType() == Schema.DisplayType.REFERENCE) {
                        addReferenceFieldToRow(targetType, record, apiName, label, row);
                    } else {
                        row.put(label, record.get(apiName));
                    }
                }
                
                // Handle Sprint if missing
                if (!sprintFieldPresent) {
                    Object sprintName = record.getSObject('Jpeto__Sprint__r') != null 
                        ? record.getSObject('Jpeto__Sprint__r').get('Name') 
                        : null;
                    row.put('Sprint', sprintName);
                }
                
                resultList.add(row);
            }
            
            // Final response
            response.put('records', resultList);
            System.debug('records --> ' + records);
            response.put('fieldSet', fieldMetadataList);
            return response;
            
        } catch (Exception ex) {
            return new Map<String, Object>{
                'records' => new List<Map<String, Object>>(),
                    'fieldSet' => new List<FieldMetadata>()
                    };
                        }
    }
    
    // Helper: add related Name in query
    private static String addReferenceFieldToQuery(Schema.SObjectType objectType, String apiName) {
        Schema.SObjectField fieldDef = objectType.getDescribe().fields.getMap().get(apiName);
        Schema.DescribeFieldResult fieldDesc = fieldDef.getDescribe();
        String relationshipName = fieldDesc.getRelationshipName();
        return (relationshipName != null) ? ', ' + relationshipName + '.Name' : '';
    }
    
    // Helper: add only the related Name into row
    private static void addReferenceFieldToRow(
        Schema.SObjectType objectType, 
        SObject record, 
        String apiName, 
        String label, 
        Map<String, Object> row
    ) {
        Schema.SObjectField fieldDef = objectType.getDescribe().fields.getMap().get(apiName);
        Schema.DescribeFieldResult fieldDesc = fieldDef.getDescribe();
        String relationshipName = fieldDesc.getRelationshipName();
        
        if (relationshipName != null) {
            SObject relObj = record.getSObject(relationshipName);
            //Object relName = relObj != null ? relObj.get('Name') : null;
            Object relName = relObj != null ? relObj : null;
            row.put(label, relName);
            /*if(relObj != null){
                System.debug('relObj --> ' + relObj);
                System.debug('label --> ' + label);
                System.debug('relName --> ' + relName);
                // Get the SObjectType from the sObject instance
                Schema.SObjectType sObjectType = relObj.getSObjectType();
                
                // Retrieve the object name (API Name)
                String objectName = sObjectType.getDescribe().getName();
                System.debug('objectName --> ' + objectName);
                System.debug('objectId --> ' + relObj.get('Id'));
                String objectRecordUrl = objectName + 'recordUrl';
                String recordUrl = '/lightning/r/'+objectName+'/'+relObj.get('Id')+'/view';
                System.debug('recordUrl --> ' + recordUrl);
                //row.put(objectRecordUrl, recordUrl);
            }*/
        } else {
            row.put(label, record.get(apiName));
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SprintWorkItemCount> getOpenWorkItemCountsBySprint(String projectId, String sprintId, String userId) {
        List<SprintWorkItemCount> result = new List<SprintWorkItemCount>();
        
        try {
            
            // Fetch valid statuses from Custom Metadata
            List<Work_Item_Status_Filter__mdt> statusRecords = [SELECT Status_Value__c FROM Work_Item_Status_Filter__mdt];
            Set<String> openStatuses = new Set<String>();
            
            for (Work_Item_Status_Filter__mdt record : statusRecords) {
                openStatuses.add(record.Status_Value__c);
            }
            
            if (openStatuses.isEmpty()) {
                // fallback: no statuses defined
                return result;
            }
            
            String baseQuery = 'SELECT Jpeto__Sprint__c, COUNT(Id) itemCount ' +
                'FROM Jpeto__Work_Item__c ' +
                'WHERE Jpeto__Project__c = :projectId ' +
                'AND Jpeto__Sprint__c != null ' +
                'AND Jpeto__Status__c IN :openStatuses';
            
            if (userId != null) {
                baseQuery += ' AND Jpeto__Assigned_User__c = :userId';
            }
            
            baseQuery += ' GROUP BY Jpeto__Sprint__c';
            
            List<AggregateResult> groupedResults = Database.query(baseQuery);
            
            for (AggregateResult ar : groupedResults) {
                String sprintIdd = (String)ar.get('Jpeto__Sprint__c');
                Integer count = (Integer)ar.get('itemCount');
                result.add(new SprintWorkItemCount(sprintIdd, count));
            }
            
            return result;
            
        } catch (Exception ex) {
            return new List<SprintWorkItemCount>();
        }
    }
    
    
    
    @AuraEnabled(cacheable=true)
    public static List<Jpeto__Project__c> getUserProjects() {
        Profile p = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        String profileName = p.Name;
        String userType = UserInfo.getUserType();
        
        if (userType == 'Guest' || userType.contains('Portal') || profileName == 'Customer Portal User' || UserType == 'CSPLitePortal' 
            || UserType == 'PowerCustomerSuccess') {
                //  Portal/Community user logic
                User u = [
                    SELECT Contact.AccountId 
                    FROM User 
                    WHERE Id = :UserInfo.getUserId()
                ];
                
                if (u.Contact == null || u.Contact.AccountId == null) {
                    return new List<Jpeto__Project__c>();
                }
                
                return [
                    SELECT Id, Name, LastModifiedDate
                    FROM Jpeto__Project__c
                    WHERE Jpeto__Client_Account__c = :u.Contact.AccountId
                    ORDER BY LastModifiedDate DESC
                    LIMIT 50
                ];
                
            }  else {
                
                List<Jpeto__Timesheet_Entry__c> latestEntry = [
                    SELECT Id, Jpeto__Work_Item__c, Jpeto__Work_Item__r.Id, Jpeto__Work_Item__r.Jpeto__Project__c, Jpeto__Work_Item__r.Name
                    FROM Jpeto__Timesheet_Entry__c
                    WHERE Jpeto__Timesheet__r.Jpeto__User__c = :UserInfo.getUserId()
                    AND Jpeto__Work_Item__c != null
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                
                if (latestEntry.isEmpty() || latestEntry[0].Jpeto__Work_Item__r == null || latestEntry[0].Jpeto__Work_Item__r.Jpeto__Project__c == null) {
                    return new List<Jpeto__Project__c>();
                }
                
                Id projectId = latestEntry[0].Jpeto__Work_Item__r.Jpeto__Project__c;
                
                
                return [
                    SELECT Id, Name, LastModifiedDate
                    FROM Jpeto__Project__c
                    WHERE Id = :projectId
                    ORDER BY LastModifiedDate DESC
                ];
            }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSortOptions() {
        String objectName = 'Jpeto__Work_Item__c';
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult describeResult = targetType.getDescribe();

        // Fetch the field set
        Schema.FieldSet fieldSet = describeResult.fieldSets.getMap().get('DefaultWorkItemFieldSet');
        List<Map<String, String>> options = new List<Map<String, String>>();

        for (Schema.FieldSetMember f : fieldSet.getFields()) {
            Map<String, String> opt = new Map<String, String>();
            if( f.getLabel() != 'Sprint' && f.getLabel() != 'Severity'  && f.getLabel() != 'Priority' && f.getLabel() != 'Record Type ID' && f.getLabel() != 'Project' && f.getLabel() != 'Status'){
                opt.put('label', f.getLabel());   // Friendly label
                //opt.put('value', f.getFieldPath()); // API Name
                opt.put('value', f.getLabel()); // same as label
                options.add(opt);
            }
        }
        return options;
    }

	@AuraEnabled(cacheable=true)
    public static List<RecordType> getWorkItemRecordTypes() {
        return [
            SELECT Id, Name 
            FROM RecordType 
            WHERE SObjectType = 'Jpeto__Work_Item__c'
            ORDER BY Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Boolean getQuickActionPermission(){
        try {
            KANBAN_Quick_Actions__c quickAction = KANBAN_Quick_Actions__c.getOrgDefaults();
            return quickAction != null && quickAction.Enable_Quick_Action__c;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Jpeto__Project_Team_Member__c> getProjectTeam(String projectId) {
        try {
        return [SELECT Id, Jpeto__Team_Member__r.Name, Jpeto__Team_Member__c, Jpeto__Role__c  FROM Jpeto__Project_Team_Member__c WHERE Jpeto__Project__c = :projectId];
        }catch (Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static string getObjectField(String objectName){
        try {
            PMT_Assignment_Configuration__mdt config = [SELECT Field_API_Name__c FROM PMT_Assignment_Configuration__mdt WHERE Object_API_Name__c = :objectName];
            return config.Field_API_Name__c;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static KANBAN_Quick_Actions__c getUserFilterSetting() {
        Id userId = UserInfo.getUserId();
        KANBAN_Quick_Actions__c setting = KANBAN_Quick_Actions__c.getInstance(userId);
        return setting;
    }

    @AuraEnabled
    public static void saveUserFilterSetting(String filterJson) {
        Id userId = UserInfo.getUserId();
        KANBAN_Quick_Actions__c setting = KANBAN_Quick_Actions__c.getInstance(userId);
        
        if (setting == null) {
            setting = new KANBAN_Quick_Actions__c(
                SetupOwnerId = userId,
                Kanban_Filters__c = filterJson
            );
        } else {
            setting.Kanban_Filters__c = filterJson;
        }

        upsert setting;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getObjectApiName(Id recordId) {
        return recordId.getSObjectType().getDescribe().getName();
    }
}