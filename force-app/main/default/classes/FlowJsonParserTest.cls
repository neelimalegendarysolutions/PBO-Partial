@IsTest
private class FlowJsonParserTest {

    @TestSetup
    static void setupData() {
        // Create a few users for testing
        List<User> users = new List<User>();

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        users.add(new User(
            FirstName = 'Test1', LastName = 'User1',
            Email = 'testuser1@example.com',
            Username = 'testuser1' + System.currentTimeMillis() + '@example.com',
            Alias = 'tu1', TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US', ProfileId = p.Id
        ));

        users.add(new User(
            FirstName = 'Test2', LastName = 'User2',
            Email = 'testuser2@example.com',
            Username = 'testuser2' + System.currentTimeMillis() + '@example.com',
            Alias = 'tu2', TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US', ProfileId = p.Id
        ));

        insert users;
    }

    @IsTest
    static void testParseJsonString_withCurrentUser() {
        User u1 = [SELECT Id FROM User WHERE Alias = 'tu1' LIMIT 1];
        User u2 = [SELECT Id FROM User WHERE Alias = 'tu2' LIMIT 1];

        // Run as user1 to simulate current user
        System.runAs(u1) {
            // Prepare mock JSON input that includes current user and another user
            String jsonData = '[{"internalId":"' + u1.Id + '","externalId":null,"Jpeto__Role__c":"Manager"},' +
                              '{"internalId":"' + u2.Id + '","externalId":null,"Jpeto__Role__c":"Developer"}]';

            FlowJsonParser.JsonInputWrapper input = new FlowJsonParser.JsonInputWrapper();
            input.jsonString = jsonData;
            input.repeaterJson = null;

            Test.startTest();
            List<FlowJsonParser.OutputWrapper> results = FlowJsonParser.parseTeamMembers(new List<FlowJsonParser.JsonInputWrapper>{ input });
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Should return one output wrapper');
            FlowJsonParser.OutputWrapper result = results[0];

            System.assertEquals(true, result.containsCurrentUser, 'Should detect current user');
            System.assertEquals('Manager', result.currentUserRole, 'Current user role should be Manager');
            System.assertEquals(1, result.teamMembers.size(), 'Only one member should remain after excluding current user');
            System.assertEquals(u2.Id, result.teamMembers[0].Jpeto__Team_Member__c, 'Remaining member should be u2');
        }
    }

    @IsTest
    static void testParseRepeaterJson_withMultipleUsers() {
        User u1 = [SELECT Id FROM User WHERE Alias = 'tu1' LIMIT 1];
        User u2 = [SELECT Id FROM User WHERE Alias = 'tu2' LIMIT 1];

        System.runAs(u2) {
            // Mock repeater JSON with two users (one is current)
            String repeaterData = '[{"Select_Role":"Tester","selectedChoiceValues":"' + u1.Id + '"},' +
                                  '{"Select_Role":"Architect","selectedChoiceValues":"' + u2.Id + '"}]';

            FlowJsonParser.JsonInputWrapper input = new FlowJsonParser.JsonInputWrapper();
            input.repeaterJson = repeaterData;

            Test.startTest();
            List<FlowJsonParser.OutputWrapper> results = FlowJsonParser.parseTeamMembers(new List<FlowJsonParser.JsonInputWrapper>{ input });
            Test.stopTest();

            System.assertEquals(1, results.size());
            FlowJsonParser.OutputWrapper result = results[0];

            System.assertEquals(true, result.containsCurrentUser, 'Current user (u2) should be detected');
            System.assertEquals('Architect', result.currentUserRole, 'Current user role should match');
            System.assertEquals(1, result.teamMembers.size(), 'Only one member should remain after excluding current user');
            System.assertEquals(u1.Id, result.teamMembers[0].Jpeto__Team_Member__c, 'Remaining member should be u1');
        }
    }

    @IsTest
    static void testParseJsonString_invalidJSON_shouldNotFail() {
        FlowJsonParser.JsonInputWrapper input = new FlowJsonParser.JsonInputWrapper();
        input.jsonString = 'invalid_json_here';
        input.repeaterJson = null;

        Test.startTest();
        List<FlowJsonParser.OutputWrapper> results = FlowJsonParser.parseTeamMembers(new List<FlowJsonParser.JsonInputWrapper>{ input });
        Test.stopTest();

        System.assertEquals(1, results.size());
        FlowJsonParser.OutputWrapper result = results[0];
        System.assertEquals(0, result.teamMembers.size(), 'No records expected for invalid JSON');
        System.assertEquals(false, result.containsCurrentUser, 'Current user should not be detected');
        System.assertEquals(null, result.currentUserRole, 'Role should be null for invalid JSON');
    }

    @IsTest
    static void testDuplicateHandling_inJsonAndRepeater() {
        User u1 = [SELECT Id FROM User WHERE Alias = 'tu1' LIMIT 1];
        User u2 = [SELECT Id FROM User WHERE Alias = 'tu2' LIMIT 1];

        System.runAs(u1) {
            // JSON with duplicate users and repeater with overlapping user
            String jsonData = '[{"internalId":"' + u2.Id + '","externalId":null,"Jpeto__Role__c":"Developer"},' +
                              '{"internalId":"' + u2.Id + '","externalId":null,"Jpeto__Role__c":"Developer"}]';
            String repeaterData = '[{"Select_Role":"Tester","selectedChoiceValues":"' + u2.Id + '"}]';

            FlowJsonParser.JsonInputWrapper input = new FlowJsonParser.JsonInputWrapper();
            input.jsonString = jsonData;
            input.repeaterJson = repeaterData;

            Test.startTest();
            List<FlowJsonParser.OutputWrapper> results = FlowJsonParser.parseTeamMembers(new List<FlowJsonParser.JsonInputWrapper>{ input });
            Test.stopTest();

            FlowJsonParser.OutputWrapper result = results[0];
            System.assertEquals(1, result.teamMembers.size(), 'Duplicates should be filtered out');
        }
    }
}