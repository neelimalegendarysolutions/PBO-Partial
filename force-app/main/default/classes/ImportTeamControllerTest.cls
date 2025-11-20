@IsTest
public class ImportTeamControllerTest {

    private static void setupTestData() {
        Id currentUserId = UserInfo.getUserId();

        // Create a client Account (required by Project validation rule)
        Account acc = new Account(Name = 'Test Client Account');
        insert acc;

        //  Create Project with required Client Account populated
        Jpeto__Project__c project = new Jpeto__Project__c(
            Name = 'Test Project',
            Jpeto__Client_Account__c = acc.Id
        );
        insert project;

        // Another Project for negative test
        Jpeto__Project__c otherProject = new Jpeto__Project__c(
            Name = 'Other Project',
            Jpeto__Client_Account__c = acc.Id
        );
        insert otherProject;

        //  Active Project Team Member (visible to controller)
        Jpeto__Project_Team_Member__c activeMember = new Jpeto__Project_Team_Member__c(
            Jpeto__Project__c = project.Id,
            Jpeto__Team_Member__c = currentUserId,
            Jpeto__Active__c = true
        );
        insert activeMember;

        //  Inactive Project Team Member (filtered out)
        Jpeto__Project_Team_Member__c inactiveMember = new Jpeto__Project_Team_Member__c(
            Jpeto__Project__c = project.Id,
            Jpeto__Team_Member__c = currentUserId,
            Jpeto__Active__c = false
        );
        insert inactiveMember;
    }

    @IsTest
    static void testGetProjects() {
        setupTestData();

        Test.startTest();
        List<Jpeto__Project__c> projects = ImportTeamController.getProjects();
        Test.stopTest();

        System.assert(!projects.isEmpty(), 'Projects should be returned');
        System.assert(projects.size() <= 100, 'Should not exceed limit 100');
        System.assertNotEquals(null, projects[0].Name, 'Project Name should not be null');
    }

    @IsTest
    static void testGetTeamMembers() {
        setupTestData();

        Id projectId = [SELECT Id FROM Jpeto__Project__c WHERE Name = 'Test Project' LIMIT 1].Id;

        Test.startTest();
        List<Jpeto__Project_Team_Member__c> members = ImportTeamController.getTeamMembers(projectId);
        Test.stopTest();

        System.assertEquals(1, members.size(), 'Only active members should be returned');
        System.assert(members[0].Jpeto__Active__c, 'Returned member should be active');
        System.assertEquals(projectId, members[0].Jpeto__Project__c, 'Returned member should belong to the correct project');
    }

    @IsTest
    static void testGetTeamMembers_NoResults() {
        setupTestData();

        Id projectId = [SELECT Id FROM Jpeto__Project__c WHERE Name = 'Other Project' LIMIT 1].Id;

        Test.startTest();
        List<Jpeto__Project_Team_Member__c> members = ImportTeamController.getTeamMembers(projectId);
        Test.stopTest();

        System.assertEquals(0, members.size(), 'No members should be returned for this project');
    }
}