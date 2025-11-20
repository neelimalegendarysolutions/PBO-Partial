public with sharing class FlowJsonParser {

    // Wrapper to receive inputs from Flow
    public class JsonInputWrapper {
        @InvocableVariable(label='Imported JSON String' description='JSON data received from LWC (optional)')
        public String jsonString;

        @InvocableVariable(label='Repeater JSON String' description='Repeater output JSON string from Flow (optional)')
        public String repeaterJson;
    }

    // Wrapper to return data back to Flow
    public class OutputWrapper {
        @InvocableVariable(label='Team Members' description='List of ready-to-insert Project Team Member records (excluding current user)')
        public List<Jpeto__Project_Team_Member__c> teamMembers;

        @InvocableVariable(label='Contains Current User' description='Indicates if the current user is part of the team')
        public Boolean containsCurrentUser;

        @InvocableVariable(label='Current User Role' description='Role of the current user, if included in the team')
        public String currentUserRole;
    }

    @InvocableMethod(
        label='Parse JSON / Repeater JSON to Project Team Member Records'
        description='Parses JSON or Flow repeater data to create unique Project Team Member records, identifies if the current user is included, and excludes them from the returned list.'
    )
    public static List<OutputWrapper> parseTeamMembers(List<JsonInputWrapper> requestList) {
        List<OutputWrapper> resultList = new List<OutputWrapper>();

        for (JsonInputWrapper req : requestList) {
            OutputWrapper output = new OutputWrapper();
            List<Jpeto__Project_Team_Member__c> members = new List<Jpeto__Project_Team_Member__c>();
            Boolean hasCurrentUser = false;
            String currentUserRole;
            Id currentUserId = UserInfo.getUserId();

            // Track unique members
            Set<String> uniqueKeys = new Set<String>();

            // Handle JSON input (from LWC)
            if (!String.isBlank(req.jsonString)) {
                try {
                    List<Object> rawList = (List<Object>) JSON.deserializeUntyped(req.jsonString);
                    for (Object obj : rawList) {
                        Map<String, Object> data = (Map<String, Object>) obj;
                        Jpeto__Project_Team_Member__c tm = new Jpeto__Project_Team_Member__c();
                        tm.Jpeto__Team_Member__c = (String) data.get('internalId');
                        tm.Jpeto__External_Team_Member__c = (String) data.get('externalId');
                        tm.Jpeto__Role__c = (String) data.get('Jpeto__Role__c');
						tm.Jpeto__Active__c = true;
                        String key = tm.Jpeto__Team_Member__c;
                        if (String.isBlank(key)) key = tm.Jpeto__External_Team_Member__c;
                        if (String.isBlank(key)) continue;

                        if (tm.Jpeto__Team_Member__c == currentUserId) {
                            hasCurrentUser = true;
                            currentUserRole = tm.Jpeto__Role__c;
                            continue;
                        } else if (!uniqueKeys.contains(key)) {
                            members.add(tm);
                            uniqueKeys.add(key);
                        }
                    }
                } catch (Exception ex) {
                    System.debug('Error parsing JSON input: ' + ex.getMessage());
                }
            }

            // Handle Repeater JSON input
            if (!String.isBlank(req.repeaterJson)) {
                try {
                    List<Object> repeaterList = (List<Object>) JSON.deserializeUntyped(req.repeaterJson);
                    for (Object obj : repeaterList) {
                        Map<String, Object> row = (Map<String, Object>) obj;
                        if (row == null) continue;

                        String roleRaw = (String) row.get('Select_Role');
                        String userId = (String) row.get('selectedChoiceValues');

                        if (String.isBlank(userId)) continue;

                        // Skip current user but capture their role
                        if ((ID)userId == currentUserId) {
                            hasCurrentUser = true;
                            currentUserRole = roleRaw;
                            continue;
                        }

                        if (!uniqueKeys.contains(userId)) {
                            Jpeto__Project_Team_Member__c tm = new Jpeto__Project_Team_Member__c();
                            tm.Jpeto__Team_Member__c = userId;
                            tm.Jpeto__Role__c = roleRaw;
                            tm.Jpeto__Active__c = true;
                            members.add(tm);
                            uniqueKeys.add(userId);
                        }
                    }
                } catch (Exception ex) {
                    System.debug('Error parsing repeater JSON: ' + ex.getMessage());
                }
            }

            // Populate output wrapper
            output.teamMembers = members;
            output.containsCurrentUser = hasCurrentUser;
            output.currentUserRole = currentUserRole;			
            resultList.add(output);
        }

        return resultList;
    }
}