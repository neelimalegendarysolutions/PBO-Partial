@RestResource(urlMapping='/myInstaller')
global  class myEndPoint {
    
        @HttpPost 
        global static string handlePost() {
             Id devRecordTypeId = Schema.SObjectType.sfLma__License__c.getRecordTypeInfosByName().get('Active').getRecordTypeId();
            RestRequest req = RestContext.request;
            blob bdata = req.requestBody;
            system.debug('bdata '+ bdata.toString());
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(bdata.toString());
           
            String orgId = '';
            string errorMessage='';
            string sandboxId='';
            string accountId='';
            string clientSecret='';
            
            if(m.containsKey('OrgId'))
            orgId =(String) m.get('OrgId');
            if(m.containsKey('errorMessage'))
            errorMessage =(String) m.get('errorMessage');
            if(m.containsKey('sandboxId'))
            sandboxId =(String) m.get('sandboxId');
            if(m.containsKey('accountId'))
            accountId =(String) m.get('accountId');
            
            if(m.containsKey('clientSecret'))
            clientSecret =(String) m.get('clientSecret');
            


            sfLma__License__c instScript = new sfLma__License__c();
            
            instScript.sfLma__Subscriber_Org_ID__c =orgId;
            
            instScript.Error_Message__c =errorMessage;
            
            instScript.Sandbox_Id__c =sandboxId;
           
            instScript.Company_Name__c =accountId;
         
            instScript.Production_id__c =clientSecret;
            instScript.sfLma__Install_Date__c=system.today();
            instScript.RecordTypeId=devRecordTypeId;
            
            insert instScript;
            return 'success';
            

            
        }
        @HttpGet 
        global static string doGet() {
            //return 'success............';
             RestRequest Request = RestContext.request;
        
        Map<String, String> RequestParams = Request.params;
        
        String orgId = RequestParams.get('orgId');
        
           
        sfLma__License__c License = [SELECT Id, sfLma__Subscriber_Org_ID__c,sfLma__License_Status__c FROM sfLma__License__c where  sfLma__Subscriber_Org_ID__c=:orgId   LIMIT 1];
        // Returning the contacts in the response
        return License.sfLma__License_Status__c;
           
            
        }
}