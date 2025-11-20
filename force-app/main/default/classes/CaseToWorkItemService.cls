global class CaseToWorkItemService {
    // Method to process the Case record in view
    @AuraEnabled
    public static String processCaseToWorkItem(Id caseId) {
        // Fetch the Case record
      Case caseRecord = [SELECT Id, IsDeleted, MasterRecordId, CaseNumber, ContactId, AccountId, ParentId, SuppliedName, SuppliedEmail, SuppliedPhone, SuppliedCompany, Type, RecordTypeId, Status, Reason, Origin, Language__c, Subject, Priority, Description, IsClosed, ClosedDate, IsEscalated, OwnerId, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, ContactPhone, ContactMobile, ContactEmail, ContactFax, Comments, LastViewedDate, LastReferencedDate, Work_Item_ID__c, Work_Item_Name__c, Work_Item_URL__c FROM Case WHERE Id = :caseId LIMIT 1];
       if(caseRecord.Work_Item_ID__c==null){
            // Fetch active custom settings for Case to WorkItem mapping
            List<Case_to_WorkItem_Mapping__c> mappings = [
                SELECT Case_Field_API_Name__c, WI_Field_API_Name__c
                FROM Case_to_WorkItem_Mapping__c
                WHERE Active__c = true
            ];
            // Construct the payload
            Map<String, Object> payload = new Map<String, Object>();
            for (Case_to_WorkItem_Mapping__c mapping : mappings) {
                String caseFieldValue = (String) caseRecord.get(mapping.Case_Field_API_Name__c);
                payload.put(mapping.WI_Field_API_Name__c, caseFieldValue);
            }
            // Send the API callout
            HttpResponse response = sendApiCallout(payload, caseRecord.Id);
            // Process the response1
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                caseRecord.Work_Item_Name__c = (String) responseBody.get('WI_Name');
                caseRecord.Work_Item_ID__c = (String) responseBody.get('WI_ID');
                caseRecord.Work_Item_URL__c = (String) responseBody.get('WI_URL');
                update caseRecord;
                // Display success message (this would typically be done in a Visualforce or Lightning component)
                System.debug('Successfully processed the Case to WorkItem mapping!' + ' : ' + response.getBody());
                return JSON.serialize(caseRecord);
            } else {
                // Handle error (this would typically involve logging the error or displaying a message to the user)
                System.debug('Error processing the Case to WorkItem mapping: ' + response.getStatus() + ' : ' + response.getBody());
                throw new CTWMException(response.getStatus() + ' : ' + Json.serialize(response.getBody()));
            }
        }
        else{
            System.debug('Work item has already been created'); 
            throw new CTWMException('Work item has already been created!');
        }
    }
    // Method to send the API callout
    private static HttpResponse sendApiCallout(Map<String, Object> payload, Id caseRecordId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:Jpetto' +  '/services/apexrest/createWorkItem?targetOrgId='+UserInfo.getOrganizationId()+'&caseUrl='+System.Url.getOrgDomainUrl().toExternalForm()
 + '/' + caseRecordId);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json;charset=UTF-8');
        System.debug('Payload: '+ JSON.serialize(payload));
        request.setBody(JSON.serialize(payload));
        System.debug('Body: '+ request.getBody());
        HttpResponse response = http.send(request);
        return response;

        
        //request.setEndpoint('https://jpettopackagingorg-dev-ed.develop.my.salesforce.com/' + targetOrgId); // Replace with your actual endpoint
        //Raw auth 
        //request.setEndpoint('https://jpettopackagingorg-dev-ed.develop.my.salesforce.com/services/apexrest/Jpetto/createWorkItem?targetOrgId='+UserInfo.getOrganizationId()); 
        //New named credential
        //request.setEndpoint('callout:Jpetto_dev' +  '/createWorkItem?targetOrgId='+UserInfo.getOrganizationId());
        //NOTE: Figure out a way for persistent authentication (uncomment for raw)
        //request.setHeader('Authorization', 'Bearer 00DDo0000022BgX!ARwAQLTl0LnjbfDgWDE49k3Vu0YtPmwFrXCuDKtyDT71m9l4Gf5Y2ZX5fF8n0msnlozTBtN9KVhG.1lfYwKm34OfjxGBEth4');
    }

    // @AuraEnabled(cacheable=true)
    // public static String returnButtonLabel() {
    //     return Label.Jpetto_Case_To_Workitem_Button_Label;
    // }

    public class CTWMException extends Exception {}
}