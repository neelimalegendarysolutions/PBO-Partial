/**
 * @description REST ful web service for creating a new Work Item record.
 */
@RestResource(urlMapping='/createWorkItem')
global without sharing class WorkItemController {
    /**
     * @description HTTP POST method to create a new Work Item record.
     */
    @HttpPost
    global static void createWorkItem() {
        String targetOrgId = RestContext.request.params.get('targetOrgId'); 
        String caseUrl = RestContext.request.params.get('caseUrl');
       Org_Id_To_Project__c oitp = [SELECT Name FROM Org_Id_To_Project__c WHERE Org_Id__c=:targetOrgId LIMIT 1];
        String projectId = oitp.Name;
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            // Parse the incoming request
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            // Create a new Work Item record
            Jpetto__Work_Item__c workItem = new Jpetto__Work_Item__c();
            // List to store attributes that don't match field API names
            List<String> unmatchedAttributes = new List<String>();
            //
            SObjectType objectType = Schema.getGlobalDescribe().get('Jpetto__Work_Item__c');
            Schema.DescribeSObjectResult describe = objectType.getDescribe();
            // Iterate over the payload and set the fields
            for (String key : payload.keySet()) {
                if (describe.fields.getMap().containsKey(key)) {
                    workItem.put(key, payload.get(key));
                } else {
                    unmatchedAttributes.add(key);
                }
            }
            // If there are unmatched attributes, return an error response
            if (!unmatchedAttributes.isEmpty()) {
                Map<String, Object> errorResponse = new Map<String, Object>{
                    'statusCode' => 400,
                    'error' => 'Invalid attributes',
                    'details' => unmatchedAttributes
                };
                res.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
                res.statusCode = 400;
                return;
            }
            // Insert the new record
            workItem.Jpetto__Project__c = projectId;
            workItem.Jpetto__Case_Url__c= caseUrl;
            insert workItem;
            workItem = [SELECT Id, Name FROM Jpetto__Work_Item__c WHERE Id =: workItem.Id];
            // Construct the URL to view the record in the partner portal
            // String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
            // String partnerPortalURL = baseURL.replace('my.salesforce.com', 'partnerportal.my.salesforce.com');
            String recordURL = Url.getSalesforceBaseUrl().toExternalForm() + '/' + workItem.Id;
            // Set the response
            Map<String, Object> responseMap = new Map<String, Object>{
                'statusCode' => 200,
                'WI_ID' => workItem.Id,
                'WI_URL' => recordURL,
                'WI_Name' => workItem.Name
            };
            res.responseBody = Blob.valueOf(JSON.serialize(responseMap));
            res.statusCode = 200;
        } catch (Exception e) {
            res.responseBody = Blob.valueOf(e.getMessage());
            res.statusCode = 500;
        }
    }
}