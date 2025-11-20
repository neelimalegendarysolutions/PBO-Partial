import { LightningElement, track, wire, api } from 'lwc';
import getProjects from '@salesforce/apex/ImportTeamController.getProjects';
import getTeamMembers from '@salesforce/apex/ImportTeamController.getTeamMembers';

export default class ImportTeamButton extends LightningElement {
    // UI and state
    @track showModal = false;
    @track selectedProject;
    @track projectOptions = [];
    @track teamData = [];
    @track selectedRows = []; // Track selected team
    @track selectedMembersDisplay = [];

    // Flow integration
    @api currentProjectId;
    @api importedTeamJson = '';

    columns = [
        { label: 'Internal Team Member', fieldName: 'internalName' },
        { label: 'External Team Member', fieldName: 'externalName' },
        { label: 'Role', fieldName: 'Jpeto__Role__c' }
    ];

    // Fetch all Projects
    @wire(getProjects)
    wiredProjects({ data, error }) {
        if (data) {
            this.projectOptions = data.map(proj => ({
                label: proj.Name,
                value: proj.Id
            }));
        } else if (error) {
            console.error('Error loading projects:', error);
        }
    }

    // Modal controls
    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    // Load team members on project change
    handleProjectChange(event) {
        this.selectedProject = event.detail.value;

        getTeamMembers({ projectId: this.selectedProject })
            .then(result => {
                this.teamData = result.map(row => ({
                    Id: row.Id,
                    internalId: row.Jpeto__Team_Member__c,
                    externalId: row.Jpeto__External_Team_Member__c,
                    internalName: row.Jpeto__Team_Member__r ? row.Jpeto__Team_Member__r.Name : '',
                    externalName: row.Jpeto__External_Team_Member__r ? row.Jpeto__External_Team_Member__r.Name : '',
                    Jpeto__Role__c: row.Jpeto__Role__c
                }));
            })
            .catch(error => {
                console.error('Error fetching team members:', error);
            });
    }

    // Handle row selection
    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    // Handle Import click
    handleImport() {
        const selectedData = this.selectedRows.length ? this.selectedRows : this.teamData;
        this.importedTeamJson = JSON.stringify(selectedData);

        // Keep members visible on main screen
        this.selectedRows = selectedData;

        // Prepare simplified display list for pills
        this.selectedMembersDisplay = selectedData.map((m, index) => ({
            key: m.Id || index,
            displayName: m.internalName || m.externalName || 'Unnamed'
        }));

        this.showModal = false;
    }

    // Remove member by index
    handleRemoveMember(event) {
        const index = event.currentTarget.dataset.index;
        this.selectedMembersDisplay.splice(index, 1);
        this.selectedMembersDisplay = [...this.selectedMembersDisplay];

        // Update underlying selectedRows & Flow JSON
        this.selectedRows.splice(index, 1);
        this.selectedRows = [...this.selectedRows];
        this.importedTeamJson = JSON.stringify(this.selectedRows);
    }
}