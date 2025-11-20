@isTest
public class MyendPointTest {
    @istest
    public static void testmethid1(){
        RestRequest request = new RestRequest();
        request.httpMethod = 'Post';
        request.addHeader('Content-Type', 'application/json');
        request.requestBody = Blob.valueof(' {"OrgId": "testing orgid","errorMessage": "error","sandboxId": "testsandbox","accountId": "Test Company llc","clientSecret": "Test Country"}');
        RestContext.request = request;
       string response= myEndPoint.handlePost();
        
    }

}