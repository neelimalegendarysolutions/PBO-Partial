import { api, LightningElement, track, wire } from 'lwc';
import { gql, graphql, refreshGraphQL } from 'lightning/uiGraphQLApi';
import getOpenWorkItemCountsBySprint from '@salesforce/apex/WorkItemControllerPMT.getOpenWorkItemCountsBySprint';
const fields = [];
export default class SprintPath extends LightningElement {
    @api projectId; /* Id the record */
    @api sprintId; /* Id of the sprint */
    @api currentUserId /* Id of the currentUser */
    @api objectApiName; /* object api name. For example, Account, Invoice__c */
    @api fieldApiName; /* field api name. For example, Rating, Status__c */
    @api values; /* picklist values comma separated if the values are not part of picklist field */
    @api currentValue; /* current value of the field */
    @api pathType; /* type of the path. For base, path */
    @api buttonLocation; /* location of the button. For top, same row */
    @api buttonLabel = 'Update Current Value'; /* label of the button */
    @api showButton = false;
    @api recordTypeName; /* record type name */

    @track pathValues = [];

    _sprintData = [];

    @api
    set sprintData(value) {
        this._sprintData = value;
        if (Array.isArray(this.pathValues) && this.pathValues.length > 0 && this.currentValue) {
            this.buildEnhancedPath();
        }
    }
    get sprintData() {
        return this._sprintData;
    }

    @track enhancedPathValues = [];
    sprints;
    graphqlData;
    isLoading = false;
    isTop = false;
    errorMessage;
    isError = false;
    recordTypeId;

    get displaySprintSection() {
        return ((this.projectId && this.sprints && this.sprints.length) || this.projectId) > 0 ? true : false;
    }

    get messageLabel() {
        return !this.projectId ? 'Please Select a Project from the Above Lookup Field' : '';
    }

    get sprintSection() {
        return (this.projectId && this.sprints && this.sprints.length === 0) ? 'display: none;' : '';
    }

    @wire(getOpenWorkItemCountsBySprint, {
        projectId: '$projectId',
        sprintId: '$sprintId',
        userId: '$currentUserId'
    })
    wiredWorkItems(result) {

       
        const { data, error } = result;
        if (data) {
          
            this.buildEnhancedPath();
            this.sprintData = data;
           
        } else if (error) {
            console.log('error');
            this.error = error;
            console.error('Error fetching work items:', error);
        }
    }

    renderedCallback() {

    }

    @track labelWithCount;
    buildEnhancedPath() {

        if (
            !Array.isArray(this.pathValues) || this.pathValues.length === 0 ||
            !Array.isArray(this.sprintData) || this.sprintData.length === 0 ||
            !this.currentValue
        ) {
            console.warn('Missing required data: pathValues, sprintData, or currentValue.');

        }


        const currentIndex = this.pathValues.findIndex(p => p.value === this.currentValue);
       
        if (currentIndex === -1) return;
        
        // Prevent reprocessing if already built


        this.enhancedPathValues = this.pathValues.map((step, index) => {
            const sprintMatch = this.sprintData.find(s => s.sprintId === step.value);
            const count = sprintMatch ? sprintMatch.count : 0;
            const hasNeglectedItems = index <= currentIndex && count > 0;
            const labelWithCount = hasNeglectedItems
                ? `  ${count}  ⬆  ${step.label}  `
                : step.label;
            this.labelWithCount = labelWithCount;


            return {
                ...step,
                hasNeglectedItems,
                neglectedCount: count,
                labelWithCount,



            };
        });
       
    }

    connectedCallback() {
        if (this.buttonLocation === 'Top') {
            this.isTop = true;
        } else {
            this.isTop = false;
        }
        fields.push(this.objectApiName + '.' + this.fieldApiName);
        if (this.recordTypeName) {
            fields.push(this.objectApiName + '.RecordTypeId');
        }
        if (this.values) {
            let allValues = this.values.split(',');
            for (let i = 0; i < allValues.length; i++) {
                this.pathValues.push({
                    label: allValues[i],
                    value: allValues[i]
                });
            }
        }
        
    }

    /*** fetching Sprint records based on selected projectId by GraphQL ***/
    @wire(graphql, {
        query: gql`
            query getSp($projectId: ID) {
            uiapi {
                query {
                    Jpeto__Sprint__c (where: {Jpeto__Project__c: {eq: $projectId}}, orderBy: {Jpeto__Start_Date__c: {order: ASC}}) {
                        edges {
                            node {
                                Id
                                Name {
                                    value
                                }
                                    CreatedDate { value }  

                                Jpeto__Project__c {
                                    value
                                }
                                Jpeto__Status__c {
                                    value
                                }
                                Jpeto__Type__c {
                                    value
                                }
                                Jpeto__Start_Date__c {
                                    value
                                }
                            }
                        }
                    }
                }
            }
        }
        `,
        variables: "$params",
    })
    graphqlQueryResult(result) {
        const { data, errors } = result;
        this.isLoading = false;

        if (data) {
            let sprintsRaw = data?.uiapi?.query?.Jpeto__Sprint__c?.edges?.map(edge => edge?.node);


            sprintsRaw.sort((a, b) => {
                const startA = a.Jpeto__Start_Date__c?.value;
                const startB = b.Jpeto__Start_Date__c?.value;

                if (startA && startB) {
                    return new Date(startA) - new Date(startB); // ASC
                } else if (!startA && !startB) {
                    // Fallback to CreatedDate DESC
                    const createdA = a.CreatedDate?.value;
                    const createdB = b.CreatedDate?.value;
                    return new Date(createdA) - new Date(createdB); //  asc
                } else if (!startA) {
                    return 1; // put nulls at end
                } else {
                    return -1;
                }
            });

            this.sprints = sprintsRaw;
            // Prepare path values
            this.pathValues = sprintsRaw.map((s) => ({
                label: s.Name?.value,
                value: s.Id
            }));


            if (this.pathValues.length > 0) {
                const latestSprint = this.pathValues[this.pathValues.length - 1];
                this.currentValue = this.projectId && this.currentValue ? this.currentValue : latestSprint.value;
            } else {
                this.currentValue = '';
            }


            this.buildEnhancedPath();           


            if (this.currentValue !== '') {
                this.dispatchEvent(new CustomEvent('pathchange', {
                    detail: { value: this.currentValue }
                }));
            }
        }

        this.graphqlData = result;
    }

    get params() {
        return {
            projectId: this.projectId ? this.projectId : ''
        };
    }

    async refresh() {
        return refreshGraphQL(this.graphqlData);
    }

    handleSelectChange(event) {
        this.isButtonClicked = true;
        event.preventDefault();
        this.currentValue = event.target.value;
        this.sprintId = this.currentValue;
        if (!this.showButton) {
            const changeEvent = new CustomEvent('change', {
                detail: {
                    value: this.currentValue
                }
            });
            this.dispatchEvent(changeEvent);
        }

        /* SprintChange evenet to Parent*/
        const patchChangeEvent = new CustomEvent('pathchange', {
            detail: {
                value: this.currentValue
            }
        });
        this.dispatchEvent(patchChangeEvent);

    }


}

function transformData(data) {
    return data?.uiapi?.query?.Jpeto__Sprint__c?.edges?.map(({ node }) => ({
        value: node.Id,
        label: node.Name.value
    })) || [];
}