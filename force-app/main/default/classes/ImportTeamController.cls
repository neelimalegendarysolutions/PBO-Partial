public with sharing class ImportTeamController {

    // Fetch all projects (you can add filters as needed)
    @AuraEnabled(cacheable=true)
    public static List<Jpeto__Project__c> getProjects() {
        return [
            SELECT Id, Name 
            FROM Jpeto__Project__c 
            ORDER BY Name 
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=false)
public static List<Jpeto__Project_Team_Member__c> getTeamMembers(Id projectId) {
    return [
        SELECT 
            Id,
        	Jpeto__Project__c,
            Jpeto__Team_Member__r.Name,
            Jpeto__External_Team_Member__r.Name,
            Jpeto__Role__c,
            Jpeto__Team_Member__c,
            Jpeto__External_Team_Member__c,
            Jpeto__Active__c
        FROM Jpeto__Project_Team_Member__c
        WHERE Jpeto__Project__c = :projectId
        AND Jpeto__Active__c = TRUE
    ];
}

}