/**
 * @description his class contains test methods for the WorkItemController class.
 * Created by vinay on 16-10-2023.
 */
@IsTest
public with sharing class WorkItemControllerTest {
    
    /**
     * @description Test Behavior Success Response
	*/
    @IsTest
    static void testBehavior(){        
        Test.startTest();
         
        
        Account a = new Account();
        a.Name = 'test acc';
        insert a;

        Jpetto__Project__c project = new Jpetto__Project__c();
        project.Name='test project';
        project.Jpetto__Client_Account__c= a.Id;
        insert project;

        Org_Id_To_Project__c oitp = new Org_Id_To_Project__c();
        oitp.put('Name',project.Id);
        oitp.put('Org_Id__c', 'TestOrgId');
        insert oitp;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String jsonMsg = '{"Jpetto__Title__c":"Test Case To Work Item Request"}';
        req.requestURI = '/services/apexrest/createWorkItem';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonMsg);
        req.params.put('targetOrgId', 'TestOrgId');
        req.params.put('caseUrl', 'TestCaseUrl');
        RestContext.request = req;
        RestContext.response= res;
        WorkItemController.createWorkItem();
        //System.assertEquals(200, res.statusCode, 'expecting 200');
        Test.stopTest();
    }
    
    /**
     * @description Test Behavior for mismatched attributes Response
	*/    
    @isTest
    static void testCreateWorkItem() {
        // Create a test user (modify as needed)
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
        User testUser = new User(
            ProfileId = profile.Id,
            LastName = 'TestUser',
            Username = 'testuser@aksmcsv.com',
            Email = 'testuser@examplexx.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
		Test.startTest();
        Org_Id_To_Project__c oitp = new Org_Id_To_Project__c();
        oitp.put('Name','TestOrgId');
        oitp.put('Org_Id__c', 'TestOrgId');
        insert oitp;
        // Set up the test REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/createWorkItem';
        req.httpMethod = 'POST';

        // Add necessary request parameters
        req.params.put('targetOrgId', 'TestOrgId');
        req.params.put('caseUrl', 'TestCaseUrl');

        // Create a sample JSON request body (modify as needed)
        String requestBody = '{"Jpetto__Title__c":"Test Case To Work Item Request1","Description__c":"Test Description"}';
        req.requestBody = Blob.valueOf(requestBody);

        // Set the current REST context
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the REST service
        WorkItemController.createWorkItem();
        
        // Verify the response
        //System.assertEquals(400, res.statusCode,'expecting 400');
        Test.stopTest();

        // You can add more assertions based on the expected behavior of your REST service.
    }
}