import { LightningElement, api, wire, track } from 'lwc';
import { getListUi } from 'lightning/uiListApi';
import { updateRecord, getRecordUi } from 'lightning/uiRecordApi';
import { gql, graphql, refreshGraphQL } from 'lightning/uiGraphQLApi';
import { refreshApex } from '@salesforce/apex';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import WORK_ITEM_OBJECT from '@salesforce/schema/Jpeto__Work_Item__c'
import STATUS_FIELD from '@salesforce/schema/Jpeto__Work_Item__c.Jpeto__Status__c'
import ID_FIELD from '@salesforce/schema/Jpeto__Work_Item__c.Id'
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import Id from '@salesforce/user/Id';

import { loadStyle } from 'lightning/platformResourceLoader';
import comboboxStyles from '@salesforce/resourceUrl/globalCombobox';

import getWorkItems from '@salesforce/apex/WorkItemControllerPMT.getWorkItems';
import getQuickActionPermission from '@salesforce/apex/WorkItemControllerPMT.getQuickActionPermission';
import getProjectTeam from '@salesforce/apex/WorkItemControllerPMT.getProjectTeam';
import getObjectField from '@salesforce/apex/WorkItemControllerPMT.getObjectField';

import getUserProjects from '@salesforce/apex/WorkItemControllerPMT.getUserProjects';
import getSortOptions from '@salesforce/apex/WorkItemControllerPMT.getSortOptions';
import getWorkItemRecordTypes from '@salesforce/apex/WorkItemControllerPMT.getWorkItemRecordTypes';
import getUserFilterSetting from '@salesforce/apex/WorkItemControllerPMT.getUserFilterSetting';
import saveUserFilterSetting from '@salesforce/apex/WorkItemControllerPMT.saveUserFilterSetting';

export default class JpettoProjectManagementTool extends NavigationMixin(LightningElement) {
    workItemRecordTypeMap = new Map();
    @track workItemRecordTypeMapTemp = new Map();
    workItemRecordTypes;
    @track workItemRecordTypesTemp;

    @track enableActionMenu = false;
    @api relatedListTitle = 'Jpetto KANBAN';
    @api isCommunity = false;
    @track communityNavigationURL;
    renderedCallback() {
        const dropdowns = document.querySelectorAll('.slds-listbox.slds-dropdown');
        dropdowns.forEach(el => {
            el.style.minWidth = 'max-content';
            el.style.whiteSpace = 'nowrap';
        });
       
    }

    records
    @track beforeRefreshRecords;
    @track workItemRecords;
    @track workItemsWireResult; // <-- holds wire result for refreshApex
    @track refreshTrigger = Date.now(); // reactive variable
    @track workItemDefaultRecordTypeId; /*Work Item Default RecordType Id*/
    workItemMasterRecordTypeId;  /*Work Item Master RecordType Id*/
    workItemSelectedRecordTypeId; /*Work Item Selected RecordType Id*/
    isMasterRecordTypeId = true;
    sprintId = ''; /*Added to fetch the work item related with particular sprint */
    pickVals
    @track recordTypes /* Added to show Count with Work item Record Type */
    @track recordTypesTemp /* Added to show Count with Work item Record Type */
    @track initalRecordTypes /* Added to show Count with Work item Record Type */
    @track updatedPickVals /* Added to show Count with Work item stage field */
    @track workItemStagePickVals
    @api recordId
    @api objectApiName;
    get isOnProjectRecordPage() {
        return this.objectApiName === 'Jpeto__Project__c';
    }
     get containerClass() {
        // Only add scroll-container if NOT on Project record page
        return this.isOnProjectRecordPage 
            ?  'slds-m-bottom_x-small scroll-container'
            : 'slds-m-bottom_x-small' ;
    }

    isSearchBoxDisabled = false;
    oldPickVal /*Added to restrict drag an item to existing list item */
    projectId
    projectName
    workItems
    graphqlData
    isLoading
    isSprintChanged = false;
    isUserChanged = false;
    fields = [];
    workItemFieldsName = [];
    displayInfo = {
        primaryField: 'Name',
        additionalFields: ['Jpeto__Client_Account__r.Name'],
    };
    userId = Id;
    currentUserId = null;

    isUpdateHandlerCalled = false;

    searchOptions = [];
    @track searchTerm = '';
    @track searchResults = [];
    @track allWorkItemRecords = []; // For client-side filtering

    isModalOpen = false;
    @track testingStage;

    @track searchKey = '';
    @track allRecordTypes = [];
    @track filteredRecordTypes = [];
    @track showDropdown = false; // controls dropdown visibility
    selectedRecordTypeId;

    @track projectTeamUsers =[];

    assignFieldApiName;
    @track refreshKey = 0;

    @wire(getObjectField, {objectName: 'Jpeto__Work_Item__c'})
    assignToFieldAPiName({ error, data}){
        if(data){
            this.assignFieldApiName = data;
            //console.log('test 1');
        }else if(error){
            console.error(error);
            this.assignFieldApiName = undefined;
        }
    }

    @wire(getProjectTeam, {
        projectId: '$projectId'})
    wiredProjectTeam({ error, data }) {
        if (data) {
            let uniqueMap = new Map();
            //console.log('test 2');
            data.forEach(record => {
                const userId = record.Jpeto__Team_Member__c;

                if (!uniqueMap.has(userId)) {
                    uniqueMap.set(userId, {
                        // Add convenience fields for radio group
                        label: `${record.Jpeto__Team_Member__r?.Name} (${record.Jpeto__Role__c})`,
                        value: userId
                    });
                }
            });

            // Final unique array
            this.projectTeamUsers = Array.from(uniqueMap.values());
            //console.log('team members', JSON.stringify(this.projectTeamUsers));
        } else if (error) {
            console.error(error);
            this.projectTeamUsers = [];
        }
    }

    @wire(getWorkItemRecordTypes)
    wiredRecordTypes({ error, data }) {
        if (data) {
            //console.log('test 3');
            this.allRecordTypes = data;
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getQuickActionPermission)
    wiredRecordTypes({ error, data }) {
        if (data) {
            this.enableActionMenu = data;
            //console.log('getQuickActionPermission--',this.enableActionMenu);
        } else if (error) {
            console.error(error);
        }
    }

    handleSearchKeyChange(event) {
        this.searchKey = event.target.value;
        if (this.searchKey.length > 0) {
            this.filteredRecordTypes = this.allRecordTypes.filter(rt =>
                rt.Name.toLowerCase().includes(this.searchKey.toLowerCase())
            );
            this.showDropdown = this.filteredRecordTypes.length > 0;
        } else {
            this.showDropdown = false; // hide dropdown if input empty
            this.filteredRecordTypes = [];
        }
    }

    handleSelectRecordType(event) {
        this.selectedRecordTypeId = event.currentTarget.dataset.id;
        const selectedRecord = this.allRecordTypes.find(rt => rt.Id === this.selectedRecordTypeId);
        this.searchKey = selectedRecord.Name;
        this.showDropdown = false; // hide dropdown after selection
    }



    openModal(event) {
        // console.log('event label --> ' + event.target.label);
        // console.log('event target --> ' + JSON.stringify(event.target));
        // console.log('event dataset --> ' + JSON.stringify(event.target.dataset));
        this.isModalOpen = true;
        this.testingStage = event.target.value;
        //console.log('testingStage --> ' + this.testingStage);
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleSuccess() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Work Item created successfully',
                variant: 'success'
            })
        );

        this.isModalOpen = false;
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Error creating Work Item',
                variant: 'error'
            })
        );
    }

    @track filtersJsonData = {};

    connectedCallback() {
         try{
            let currentURL = window.location.pathname;

        if(this.isCommunity){
            let trimURL = currentURL.substring(0, currentURL.indexOf('/s/')+3);
            this.communityNavigationURL = trimURL + 'detail';
        }
        }catch(ex){
            console.log('Path Track Error:::', ex);
        }
        loadStyle(this, comboboxStyles);
       // this.currentUserId = this.userId;
        if(this.recordId != undefined){
            this.projectId = this.recordId;
            this.isSearchBoxDisabled = true;
            this.selectedProjectId = this.projectId;
        }

        Promise.resolve().then(() => {
            const defaultTab = this.tabs.find(tab => tab.isActive);
            if (defaultTab) {
                // Fire handleActive for the default tab once
                this.handleActive({ detail: { value: defaultTab.recordTypeId } });
            }
        });

        this.loadSavedFilters();

        //  Keep reference so it’s not garbage-collected
        this._boundResizeHandler = this.handleResize.bind(this);
        window.addEventListener('resize', this._boundResizeHandler);
        this.handleResize(); // run once on load
    }

    handleResize() {
        this._isMobile = window.innerWidth <= 768;       
    }
    
    disconnectedCallback() {
        //  Clean up when component is destroyed
        if (this._boundResizeHandler) {
            window.removeEventListener('resize', this._boundResizeHandler);
        }
    }



    async loadSavedFilters() {
        try {
            const setting = await getUserFilterSetting();
            // console.log('setting --> ' + JSON.stringify(setting));
            // console.log('setting.Kanban_Filters__c --> ' + JSON.stringify(setting.Kanban_Filters__c));
            if (setting && setting.Kanban_Filters__c) {
                this.filtersJsonData = JSON.parse(setting.Kanban_Filters__c);
                //console.log('filtersJsonData --> ' + JSON.stringify(this.filtersJsonData));
                const searchIn = this.filtersJsonData.searchIn;
                const searchText = this.filtersJsonData.searchText;
                const workItems = this.filtersJsonData.workItems;
                // Combine all filters into one JSON object
                this.selectedSearchPicklistValue = searchIn;
                this.searchTerm = searchText;
                this.selectedRadioValue = workItems;
                if(this.selectedRadioValue == 'All Work Items'){
                    this.selectedRadioFilterValue = 'All';
                    this.checkedAllRadioFilter = true;
                    this.checkedMyRadioFilter = false;
                }else{
                    this.selectedRadioFilterValue = 'My';
                    this.checkedMyRadioFilter = true;
                    this.checkedAllRadioFilter = false;
                }
                setTimeout(() => {
                    this.filterData(); // or this.searchData(); for server-side
                }, 2000);
                
                // console.log('selectedRadioFilterValue --> ' + this.selectedRadioFilterValue);
                // console.log(searchIn, searchText, workItems);
                // console.log('filtersJsonData --> ' + JSON.stringify(this.filtersJsonData));
            }else{
                this.handleFilterClear();
            }
        } catch (error) {
            console.error('Error loading filters: ', error);
        }
    }

    // 🔹 Helper that safely calls handleActive with consistent shape
    triggerHandleActive() {
        if (typeof this.handleActive === 'function' && this.activeRecordTypeId) {
            // Mimic the event shape expected by your handleActive
            this.handleActive({ target: { value: this.activeRecordTypeId } });
        }
    }

    @wire(getUserProjects)
        wiredProjects({ error, data }) {
            //console.log('test 4');
            if (data && data.length >= 1) {
                //console.log('data.length', data.length);
                // Only set default if recordId is not already provided
                if (!this.recordId) {
                    this.projectId = data[0].Id;   // most recent or only project
                    this.displayInfo = true;
                //  this.isSearchBoxDisabled = data.length === 1;
                    this.selectedProjectId = this.projectId;
                    this.projectName = data[0].Name;
                    //console.log('this.projectName',this.projectName);
                    //console.log('this.projectId  ',this.projectId );
                }
            } else if (error) {
            console.error(error);
        }
    }

    @wire(getSortOptions)
    wiredOptions({ error, data }) {
        //console.log('test 5');
        if (data) {
            this.sortOptions = data;
            this.selectedSortField = data[0].value; // default first field

            //console.log('sortOptions --> ' + JSON.stringify(this.sortOptions));
            //console.log('selectedSortField --> ' + this.selectedSortField);
        } else if (error) {
            console.error(error);
        }
    }

    listKey = 0;
   
    @wire(getWorkItems, {
        projectId: '$projectId',
        sprintId: '$sprintId',
        recordTypeId: '$workItemDefaultRecordTypeId',
        isMasterRecordTypeId: '$isMasterRecordTypeId',
        userId: '$currentUserId',
        refreshTrigger: '$refreshTrigger'
    })
    wiredWorkItems(result) {
        this.isLoadingWorkItem = true; // 🔹 show spinner immediately
        this.workItemsWireResult = result;

        const { data, error } = result;

        if (error) {
            console.error('Error fetching work items:', error);
            this.error = error;
            this.isLoadingWorkItem = false; // 🔹 hide spinner on error
            return;
        }

        if (!data) return;

        try {
            this.error = undefined;
            this.allWorkItemRecords = [...data.records];
            //this.searchOptions = data.fieldSet || [];
            this.searchOptions = data.fieldSet
                                .filter(item => item.value !== 'Sprint')
                                .map(option => {
                                    // Check if this option is related to record type
                                    if (option.label && option.label.toLowerCase().includes('record type') || 
                                        option.value && option.value.toLowerCase().includes('recordtype')) {
                                        return {
                                            label: 'Record Type Name',
                                            value: option.value // Keep the original value for filtering
                                        };
                                    }
                                    return option;
                                }) || [];

            // Remove Sprint Name
            this.workItemRecords = this.allWorkItemRecords.map(record => {
                const { ['Sprint Name']: removed, ...rest } = record;
                return rest;
            });

            // --- Sorting ---
            const sortFn = (a, b) => {
                const severityA = this.getSeverityNumber(a.Severity);
                const severityB = this.getSeverityNumber(b.Severity);
                if (severityA !== severityB) return severityA - severityB;
                const priorityOrder = v => (v === '911' ? 0 : parseInt(v || '999', 10));
                return priorityOrder(a.Priority) - priorityOrder(b.Priority);
            };
            this.workItemRecords.sort(sortFn);
            this.allWorkItemRecords.sort(sortFn);

            // --- Rebuild record type counts ---
            if (
                (this.workItemDefaultRecordTypeId === this.workItemMasterRecordTypeId ||
                    this.isSprintChanged ||
                    this.isUserChanged) &&
                this.recordTypesTemp &&
                this.projectId
            ) {
                this.isSprintChanged = false;
                this.isUserChanged = false;
                this.workItemDefaultRecordTypeId = this.workItemSelectedRecordTypeId;
                this.recordTypesTemp = [...this.initalRecordTypes];
                this.workItemRecordTypeMapTemp.clear();

                const recordTypeCountMap = new Map();
                const recordTypeNameToIdMap = new Map();

                this.recordTypesTemp.forEach(rt => {
                    recordTypeCountMap.set(rt.recordTypeId, 0);
                    recordTypeNameToIdMap.set(rt.name, rt.recordTypeId);
                });

                this.allWorkItemRecords.forEach(item => {
                    const recordTypeObj = item["Record Type ID"];
                    const recordTypeName = recordTypeObj?.Name || recordTypeObj?.name;
                    if (!recordTypeName) return;

                    const rtId = recordTypeNameToIdMap.get(recordTypeName);
                    if (rtId) {
                        recordTypeCountMap.set(rtId, (recordTypeCountMap.get(rtId) || 0) + 1);
                    }
                });

                const masterId = this.recordTypesTemp.find(rt => rt.master)?.recordTypeId;
                if (masterId) {
                    recordTypeCountMap.set(masterId, this.allWorkItemRecords.length);
                }

                this.workItemRecordTypeMapTemp = recordTypeCountMap;

                // --- Update tab names with count ---
                this.recordTypesTemp = this.recordTypesTemp.map(rt => {
                    const count = recordTypeCountMap.get(rt.recordTypeId) || 0;
                    const cleanLabel = rt.master ? 'All' : rt.name.replace(/\(\d+\)$/, '').trim();
                    return { ...rt, name: `${cleanLabel} (${count})` };
                });
                this.workItemRecordTypesTemp = [...this.recordTypesTemp];

                // --- Filter for active tab ---
                const activeRecordTypeId = this.activeRecordTypeId || masterId;
                this.workItemRecords = this.allWorkItemRecords.filter(item => {
                    const recordTypeObj = item["Record Type ID"];
                    const recordTypeName = recordTypeObj?.Name || recordTypeObj?.name;
                    if (!recordTypeName) return false;

                    if (activeRecordTypeId === masterId) return true;
                    const mappedId = recordTypeNameToIdMap.get(recordTypeName);
                    return mappedId === activeRecordTypeId;
                });

                this.initializeDefaultTab();
            }

            // --- Update UI and children ---
            if (this.pickVals) {
                this.updateStageCountsFrom(this.workItemRecords);
            }

            const children = this.template.querySelectorAll('c-drag-and-drop-list');
            children.forEach(child => child.updateRecordsData(this.workItemRecords));

            this.listKey = Date.now();

           // console.log('✅ workItemRecords refreshed', JSON.stringify(this.workItemRecords));
        } finally {
            this.isLoadingWorkItem = false; // 🔹 hide spinner after data done
        }
    }


    clearWorkItemsIfNoCount() {
        const selectedType = this.recordTypesTemp.find(
            item => item.recordTypeId === this.workItemDefaultRecordTypeId
        );

        if (selectedType) {
            const match = selectedType.name.match(/\((\d+)\)/);
            const count = match ? parseInt(match[1], 10) : 0;
            if (count === 0) {
                this.workItemRecords = [];

                // Reset all stage counts to 0
                this.workItemStagePickVals = (this.pickVals || []).map(stage => ({
                    stage,
                    title: `${stage} (0)`,
                    count,
                }));

                //console.log('workItemStagePickVals --> ' + JSON.stringify(this.workItemStagePickVals));
            }
        }
    }

    get tabs() {
        if (!this.recordTypesTemp) return [];

        return this.recordTypesTemp.map(tab => {
            const isActive = tab.recordTypeId === this.activeRecordTypeId;
            const count = this.workItemRecordTypeMapTemp?.get(tab.recordTypeId) || 0;

            return {
                ...tab,
                displayName: tab.name === 'Master' ? `All (${count})` : `${tab.name} (${count})`,
                className: 'slds-tabs_default__item ' + (isActive ? 'slds-is-active' : ''),
                tabIndex: isActive ? '0' : '-1',
                contentClass: 'slds-tabs_default__content ' + (isActive ? 'slds-show' : 'slds-hide')
            };
        });
    }

    // Getter to return true false if any selected project is having sprint or not
    get displayWorkItemStageSection() {
        return (this.sprintId != '' || (this.projectId && this.sprintId == '')) ? true : false;
    }

    get chunkedFields() {
        if (!this.fields) return [];
        const chunks = [];
        for (let i = 0; i < this.fields.length; i += 6) {
            const chunk = this.fields.slice(i, i + 6);
            chunks.push({ rowId: `row-${i}`, fields: chunk });
        }
        return chunks;
    }

    selectedSearchPicklistValue = 'All';

    initializeDefaultTab() {
        if (!this.activeRecordTypeId && this.recordTypesTemp?.length) {
            // Prefer the Master record type, fallback to the first record type
            const defaultTab = this.recordTypesTemp.find(rt => rt.recordTypeId === this.workItemMasterRecordTypeId) || this.recordTypesTemp[0];

            if (defaultTab) {
                this.activeRecordTypeId = defaultTab.recordTypeId;
                this.handleActive({ target: { value: defaultTab.recordTypeId } });
            }
        }
    }

    handleTabClick(event) {
        const clickedId = event.currentTarget.dataset.id;
        this.activeRecordTypeId = clickedId;
        
        this.handleActive({ target: { value: clickedId } });
        //('activeRecordTypeId --> ' + this.activeRecordTypeId);
       // console.log('clickedId --> ' + clickedId);
    }

    handleSearchPicklistChange(event) {
       
        this.selectedSearchPicklistValue = event.detail.value;
        // Find the label for the selected value      
        this.searchTerm = '';

        // Optionally re-filter the data to reflect the picklist change
        this.filterData();


    }

    handleSearchChange(event) {
       
        this.searchTerm = event.target.value;
         //this.isLoadingWorkItem = true;
         //console.log('test 11');
          refreshApex(this.workItemsWireResult)        
        .then(() => {
            setTimeout(() => {
                this.isLoadingWorkItem = false;
            }, 5000);
        })
        .catch(error => {
            console.error('Error in search refresh/filter:', error);
            //this.isLoadingWorkItem = false;
        });
        this.filterData(); // or this.searchData(); for server-side

    }

    filterData() { // Example client-side filtering

        // console.log('filterData called');
        // console.log('searchTerm --> ' + this.searchTerm);
        // console.log('selectedSearchPicklistValue --> ' + this.selectedSearchPicklistValue);

        if (this.searchTerm) {           

            if (this.selectedSearchPicklistValue === 'All') {

                const filteredRecords = this.allWorkItemRecords.filter(record =>
                    Object.values(record).some(value =>
                        String(value).toLowerCase().includes(this.searchTerm.toLowerCase())
                    )
                );
                this.workItemRecords = filteredRecords.map(record => {
                    const { ['Sprint Name']: removed, ...rest } = record;
                    return rest;

                });

            }
            if (this.selectedSearchPicklistValue === 'Sprint') {

                const filteredRecords = this.allWorkItemRecords.filter(record =>
                    Object.values(record).some(value =>
                        String(value).toLowerCase().includes(this.searchTerm.toLowerCase())
                    )
                );
                this.workItemRecords = filteredRecords.map(record => {
                    const { ['Sprint Name']: removed, ...rest } = record;
                    return rest;
                });
            }
            else {
                //console.log('else part of if');
                const searchTerm = this.searchTerm.toLowerCase();
                const selectedField = this.selectedSearchPicklistValue;

                const filteredRecords = this.allWorkItemRecords.filter(record => {
                    if (selectedField === 'All') {
                        // Search all fields
                        return Object.values(record).some(value =>
                            String(value).toLowerCase().includes(searchTerm)
                        );
                    }

                    else if (record.hasOwnProperty(selectedField)) {
                        // Search in selected field only
                        /*const fieldValue = record[selectedField];                       
                        return fieldValue && String(fieldValue).toLowerCase().includes(searchTerm);*/
                        let fieldValue = record[selectedField];

                        // Handle reference fields (Assigned User, Assigned Contact, Record Type ID)
                        if (typeof fieldValue === "object" && fieldValue !== null) {
                            fieldValue = fieldValue.Name ?? fieldValue.Id;
                        }

                        return fieldValue && String(fieldValue).toLowerCase().includes(searchTerm);
                    } else {
                        // Key doesn't exist, skip record
                        console.warn(`Field '${selectedField}' not found in record`, record);
                        return false;
                    }
                });
                this.workItemRecords = filteredRecords.map(record => {
                    const { ['Sprint Name']: removed, ...rest } = record;
                    return rest;
                });

                // console.log('searchTerm --> ' + searchTerm); 
                // console.log('selectedField --> ' + selectedField); 
                // console.log('allWorkItemRecords --> ' + this.allWorkItemRecords.length); 
                // console.log('filteredRecords --> ' + filteredRecords.length); 
                // console.log('filteredRecords --> ' + this.workItemRecords.length); 

            }
             //console.log('updateStageCountsFrom 627');
            this.updateStageCountsFrom(this.workItemRecords);
        }

        else {
            //console.log('else part empty searchTerm');

            const filteredRecords = this.allWorkItemRecords.map(record => {
                const { ['Sprint Name']: removed, ...rest } = record;
                return rest;
            });
            this.workItemRecords = filteredRecords;
            // console.log('updateStageCountsFrom 638');
            this.updateStageCountsFrom(this.workItemRecords);
        }

        //console.log('filterData calleddd');
    }

    workItemValue = '';


   selectedRadioValue = '';
   @track checkedAllRadioFilter = true;
   @track checkedMyRadioFilter = false;



handleRadioChange(event) {
    const selectedLabel = event.target.label;
    this.selectedRadioValue = selectedLabel;
    if(selectedLabel == null || selectedLabel == undefined){
        if(event.detail.value == 'My'){
            this.selectedRadioValue = 'My Work Items' ;
        }else{
            this.selectedRadioValue = 'All Work Items' ;
        }
    }
    //if(selectedLabel == null)
    //console.log('selected value', selectedLabel);
    // 1. Determine the correct user ID for the wire parameter
    if (this.selectedRadioValue === 'My Work Items') {
        this.currentUserId = this.userId; // Set the ID for the wire service to use
        this.checkedMyRadioFilter = true;
        this.checkedAllRadioFilter = false;
    } else { // 'All Work Items'
        this.currentUserId = null; // Clear the ID so the wire service gets all items
        this.checkedAllRadioFilter = true;
        this.checkedMyRadioFilter = false;
    }
    
    // 2. Set loading state to true and refresh the data
    // We use a timeout to ensure the UI has a chance to render the spinner
    // before the potentially-fast (cached) refreshApex() call completes.
    setTimeout(() => {
        //this.isLoadingWorkItem = true;
        //console.log('test 12');
        refreshApex(this.workItemsWireResult)
            .then(() => {
                // The data has been refreshed. Hide the spinner.
                setTimeout(() => {
                    this.isLoadingWorkItem = false;
                }, 5000);
            })
            .catch(error => {
                // Always hide the spinner, even on error.
                console.error('Error refreshing:', error);
                this.isLoadingWorkItem = false;
            });
    }, 0);
}



    @wire(getRecordUi, {
        recordIds: "$projectId",
        layoutTypes: "Compact",
        modes: "View",
    })
    wiredRecord({ error, data }) {
        //console.log('test 6');
        if (data) {
            const record = data.records[this.projectId];
            // Assuming `data` contains your layout and records data
            const layouts = data.layouts.Jpeto__Project__c;  // Access the layouts for Jpeto__Project__c

            // Get the first (and only) recordTypeId available in layouts (as there is only one record)
            const recordTypeId = Object.keys(layouts)[0];  // Only one recordTypeId

            // Check if layout data for the specific recordTypeId exists
            const layoutMap = layouts[recordTypeId];
            if (layoutMap && layoutMap.Compact && layoutMap.Compact.View && layoutMap.Compact.View.sections) {
                // Extract the sections from the layoutMap (assuming Compact View is available)
                const layoutItems = layoutMap.Compact.View.sections;
                const fields = layoutItems.reduce((acc, section) => {
                    section.layoutRows.forEach(row => {
                        row.layoutItems.forEach(item => {
                            const label = item.label;
                            const apiName = item.layoutComponents[0]?.apiName;
                            let id = '';

                            //Captureing the ProjectName
                            if (apiName === 'Name') {
                                this.projectName = record?.fields[apiName]?.value || null;
                            }
                            if (apiName !== 'RecordTypeId' && apiName !== 'Name' && acc.length < 5) {
                                const record = Object.values(data.records)[0]; // Get the first record
                                let fieldValue = null;
                                if (apiName === 'Jpeto__Client_Account__c') {
                                    fieldValue = record?.fields?.Jpeto__Client_Account__r?.displayValue || null;
                                    const accId = record?.fields[apiName]?.value || null;
                                    id = accId;

                                } else {
                                    fieldValue = record?.fields[apiName]?.value || null;
                                }
                                // Explicitly create an object with only label and value
                                acc.push({ label: label, value: fieldValue, id: id });
                            }
                        });
                    });

                    return acc;
                }, []);
                this.fields = fields;
            }
        } else if (error) {
            console.error("Error fetching compact layout fields:", error);
        }
    }



    // Getter to dynamically build the query string
    get dynamicQuery() {
        // Convert field list into GraphQL-safe node selection
        let nodeFields;

        // Extract apiName array
        const apiNames = this.workItemFieldsName.map(field => field.apiName);

        // Extract label array
        const labels = this.workItemFieldsName.map(field => field.label);


        if (apiNames) {
            nodeFields = apiNames.map(f => {
                return `${f} { value }`;
            }).join('\n');
        }

        // Construct the full query
        let query;
        if (this.workItemDefaultRecordTypeId && this.workItemDefaultRecordTypeId === this.workItemMasterRecordTypeId) {

            if (this.currentUserId) {
                query = gql`
                    query getwI($projectId: ID, $sprintId: ID, $currentUserId: ID) {
                        uiapi {
                            query {
                                Jpeto__Work_Item__c (where: {Jpeto__Project__c: {eq: $projectId},Jpeto__Assigned_User__c: {eq: $currentUserId}, , or: [{ Jpeto__Sprint__c: { eq: $sprintId } }, { Jpeto__Sprint__c: { eq: null } }]}) {
                                    edges {
                                        node {
                                            Id
                                            ${nodeFields}
                                        }
                                    }
                                }
                            }
                        }
                    }
                `;
            } else {
                query = gql`
                    query getwI($projectId: ID, $sprintId: ID) {
                        uiapi {
                            query {
                                Jpeto__Work_Item__c (where: {Jpeto__Project__c: {eq: $projectId} , or: [{ Jpeto__Sprint__c: { eq: $sprintId } }, { Jpeto__Sprint__c: { eq: null } }]}) {
                                    edges {
                                        node {
                                            Id
                                            ${nodeFields}
                                        }
                                    }
                                }
                            }
                        }
                    }
                `;
            }
        } else {
            if (this.currentUserId) {
                query = gql`
                    query getwI($projectId: ID, $sprintId: ID, $workItemDefaultRecordTypeId: ID, $currentUserId: ID) {
                        uiapi {
                            query {
                                Jpeto__Work_Item__c (where: {Jpeto__Project__c: {eq: $projectId},Jpeto__Assigned_User__c: {eq: $currentUserId}, or: [{ Jpeto__Sprint__c: { eq: $sprintId } }, { Jpeto__Sprint__c: { eq: null } }], RecordTypeId: { eq: $workItemDefaultRecordTypeId }}) {
                                    edges {
                                        node {
                                            Id
                                            ${nodeFields}
                                        }
                                    }
                                }
                            }
                        }
                    }
                `;
            } else {
                query = gql`
                    query getwI($projectId: ID, $sprintId: ID, $workItemDefaultRecordTypeId: ID) {
                        uiapi {
                            query {
                                Jpeto__Work_Item__c (where: {Jpeto__Project__c: {eq: $projectId}, or: [{ Jpeto__Sprint__c: { eq: $sprintId } }, { Jpeto__Sprint__c: { eq: null } }], RecordTypeId: { eq: $workItemDefaultRecordTypeId }}) {
                                    edges {
                                        node {
                                            Id
                                            ${nodeFields}
                                        }
                                    }
                                }
                            }
                        }
                    }
                `;
            }
        }
        return query;
    }

    // Getter to return the parameters for the GraphQL query
    get params() {
        return {
            projectId: this.projectId ? this.projectId : '',
            workItemDefaultRecordTypeId: this.workItemDefaultRecordTypeId ? this.workItemDefaultRecordTypeId : '',
            sprintId: this.sprintId ? this.sprintId : '',
            currentUserId: this.currentUserId ? this.currentUserId : ''
        };
    }



    /** Fetch metadata abaout the workItem object**/
    @wire(getObjectInfo, { objectApiName: WORK_ITEM_OBJECT })
    objectInfo({ data, error }) {
        //console.log('test 7');
        if (data) {
            this.recordTypes = Object.values(data.recordTypeInfos);
            this.recordTypesTemp = Object.values(data.recordTypeInfos);
            this.initalRecordTypes = Object.values(data.recordTypeInfos);
            if (!this.workItemMasterRecordTypeId) {
                this.workItemMasterRecordTypeId = this.recordTypes[0].recordTypeId;

            }
            this.initializeDefaultTab();
        }
        if (error) {
            console.error(error)
        }
    }

    /** Fetch recordtype metadata of workitem object **/
    @wire(getPicklistValues, {
        recordTypeId: '$workItemDefaultRecordTypeId',
        fieldApiName: STATUS_FIELD
    }) stagePicklistValues({ data, error }) {
        //console.log('test 8');
        if (data) {
            this.pickVals = data.values.map(item => item.value)
            //console.log('pickValues--', JSON.stringify(this.pickVals));
        }
        if (error) {
            console.error(error)
        }
    }

    navigateProjectHandler(event) {
        event.preventDefault()
        this.navigateHandler(event.target.dataset.id, 'Account');
    }

    navigateHandler(Id, apiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: Id,
                objectApiName: apiName,
                actionName: 'view',
            },
        });
    }

    handleActive(event) {
    this.searchTerm = '';
    const tab = event.target;
    //console.log('tab value --> ' + tab.value);
    this.workItemDefaultRecordTypeId = tab.value;
    this.workItemSelectedRecordTypeId = tab.value;

    // console.log('workItemDefaultRecordTypeId --> ' + this.workItemDefaultRecordTypeId);
    // console.log('workItemSelectedRecordTypeId --> ' + this.workItemSelectedRecordTypeId);
    // console.log('workItemMasterRecordTypeId --> ' + this.workItemMasterRecordTypeId);

    if (this.workItemSelectedRecordTypeId === this.workItemMasterRecordTypeId) {
        this.isMasterRecordTypeId = true;
    } else {
        this.isMasterRecordTypeId = false;
    }

    // Use a small timeout to ensure the UI has time to update with the new
    // recordTypeId before we start the refresh process.
    setTimeout(() => {
        // Set isLoading to true RIGHT BEFORE you call the async operation
        //this.isLoadingWorkItem = true;
        //console.log('test 13');
        refreshApex(this.workItemsWireResult)
            .then(() => {
                // Success, hide the spinner
                setTimeout(() => {
                    this.isLoadingWorkItem = false;
                }, 5000);
                //this.isLoadingWorkItem = false;

            })
            .catch(error => {
                // Always hide the spinner, even on error
                console.error('Error refreshing:', error);
                this.isLoadingWorkItem = false;
            });
    }, 0);

    if (this.isUpdateHandlerCalled) {
        this.isUpdateHandlerCalled = false;
    }
}


    /****getter to calculate the  width dynamically*/
    get calcWidth() {
        const baseWidth = this._isMobile ? 350 : 100;
        return `width: calc(${baseWidth}vw / 5)`;
    }

    handleRecordChange(event) {
        const recordId = event.detail.recordId;
        this.projectId = event.detail.recordId;
        this.selectedProjectId = event.detail.recordId;
        this.sprintId = '';
       this.projectName = '';//
        this.workItemRecordTypeMap.clear();
        this.workItemRecordTypeMapTemp.clear();
        this.searchOptions = [];
        this.currentUserId = null;// this.userId; //recent change to fix the issue while changing project

        if (!recordId) {
            this.showFilters = false;
            this.searchTerm = '';
            this.selectedSearchPicklistValue = '';
            this.workItemRecords = [];
            this.allWorkItemRecords = [];
            this.activeRecordTypeId='';
            this.refreshKey = '';
        }

        // ✅ Reset tabs to "Master" record type
        if (recordId && this.recordTypesTemp && this.recordTypesTemp.length > 0) {
            this.isLoadingWorkItem = true;
            requestAnimationFrame(() => {
                // Find all tab <a> elements
                const tabs = this.template.querySelectorAll('.slds-tabs_default__link');
                if (tabs.length > 0) {
                    const firstTab = tabs[0];
                    const firstId = firstTab.dataset.id;

                    // ✅ Update JS tracking
                    this.activeRecordTypeId = firstId;

                    // ✅ Fire your handler programmatically (same as user click)
                    this.handleTabClick({
                        currentTarget: { dataset: { id: firstId } }
                    });

                    // ✅ Optionally, mark it active in UI manually
                    tabs.forEach(tab => tab.closest('li').classList.remove('slds-is-active'));
                    firstTab.closest('li').classList.add('slds-is-active');
                    //console.log('activeRecordTypeId', this.activeRecordTypeId);
                    setTimeout(() => this.handleProjectWorkItemRefresh(), 300);
                }
            });
            //console.log('handleRecordChange end', JSON.stringify(this.workItemsWireResult));
            this.isLoadingWorkItem = false;
        }
    }

    handleListItemDrag(event) {
        this.recordId = event.detail.recordId;
        this.oldPickVal = event.detail.oldStage;
    }

    handleItemDrop(event) {
        let stage = event.detail.stage;
        //console.log('event details', JSON.stringify(event.detail));
        if (stage !== this.oldPickVal) {
            this.updateHandler(stage);
        } else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Attention!',
                    message: 'To update the workItem record stage, Please drag it to another stage',
                    variant: 'warning'
                })
            )
        }
    }

    /* Event get from sprint component to store sprintId*/
    handlePathChange(event) {

        this.sprintId = event.detail.value != undefined ? event.detail.value : '';

        this.isSprintChanged = true;


        this.isMasterRecordTypeId = true;

    }
    @track closingComments = '';
    handleWorkItemClose(event){
        //console.log('handleWorkItemClose called');
        let stage = event.detail.action;
        // console.log('event details', event.detail);
        // console.log('event detail action', event.detail.action);
        // console.log('event detail recordId', event.detail.recordId);
        // console.log('recordId ---> ' + this.recordId);
        this.recordId = event.detail.recordId;
        this.closingComments = event.detail.closingComments;
        // console.log('recordId ---> ' + this.recordId);
        // console.log('stage ---> ' + stage);
        if (stage == 'close') {
            stage = 'Closed';
            this.updateHandler(stage);
        } else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'WorkItem Closed!',
                    message: 'There is some issue with workItem Update',
                    variant: 'error'
                })
            )
        }
    }

    handleMoveToStage(event) {
        let stage = event.detail.newStage;
        this.recordId = event.detail.recordId;
        if (stage !== event.detail.oldStage) {
            this.updateHandler(stage);
        } else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Attention!',
                    message: 'To update the workItem record stage, Please drag it to another stage',
                    variant: 'warning'
                }));
        }
    }

    handleLogHours(event) {
        //console.log('handleLogHours called');
        try {

            this.handleProjectWorkItemRefresh();
        } catch (error) {
            console.error('Error refreshing data:', error);
        }
        //console.log('handleLogHours calledd');
    }

    @track assignee;
    handleAssign(event) {
        let stage = event.detail.newStage;
        this.assignee = event.detail.assignee;
        this.recordId = event.detail.recordId;
        this.updateHandler(stage);
    }


    /*async updateHandler(stage) {

        // console.log('updateHandler start');
        // console.log('recordId ---> ' + this.recordId);
        // console.log('stage ---> ' + stage);
        // console.log('updateHandler end');
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        let message ='Stage updated Successfully';
        fields[STATUS_FIELD.fieldApiName] = stage;
        if(this.closingComments)
            fields['Closing_Comments__c'] = this.closingComments;
        if(this.assignee && this.assignFieldApiName){
            fields[this.assignFieldApiName] = this.assignee.value;
            message = 'Record Assigned Successfully to ' + this.assignee.label;
        }
        
        
        const recordInput = { fields }
        await updateRecord(recordInput)
            .then(() => {
                this.showToast(message);

                this.isUpdateHandlerCalled = true;
                this.closingComments = '';
                refreshApex(this.workItemsWireResult);
                this.assignee=undefined;
            }).catch(error => {
                console.error(error);
                this.closingComments = '';
                this.assignee=undefined;
                this.showErrorToast();
            })

    }*/
    async updateHandler(stage) {
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        let message ='Stage updated Successfully';
        fields[STATUS_FIELD.fieldApiName] = stage;
        //console.log('1', this.recordId);
        let valueChanged = false;
        //console.log('2', fields[ID_FIELD.fieldApiName]);
        if(this.closingComments)
            fields['Closing_Comments__c'] = this.closingComments;
        //console.log('3');
        if(this.assignee && this.assignFieldApiName){
            let assigneeId = this.assignee.value;
            valueChanged = true;
            fields[this.assignFieldApiName] = assigneeId;
            message = 'Record Assigned Successfully to ' + this.assignee.label;
        }
        //console.log('4', JSON.stringify(fields));
        const recordInput = { fields };
        //console.log('5', JSON.stringify(recordInput));
        try {
            await updateRecord(recordInput);

            this.showToast(message);
            this.isUpdateHandlerCalled = true;
            this.closingComments = '';
            this.assignee = undefined;
            
            //console.log('test 14');
            refreshApex(this.workItemsWireResult);
            
            

        } catch (error) {
            console.error(error);
            this.closingComments = '';
            this.assignee = undefined;
            this.showErrorToast();
        }
    }

    showToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: message,
                variant: 'success'
            })
        )
    }

    showErrorToast() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Attention!',
                message: 'This stage does not related to current workitem record type, Please drag the workitem to another stage',
                variant: 'warning'
            })
        )
    }    

    getSeverityNumber(severity) {
        if (typeof severity !== 'string') {

            return 999;
        }
        const match = severity.match(/^(\d+)/);
        return match ? parseInt(match[1], 10) : 999;
    }



    @track showFilters = false;
    toggleShowFilters() {

        if (this.isRecordSelected) {
            this.showFilters = !this.showFilters;
        }
    }

    @track selectedProjectId = null;

    get isRecordSelected() {

        return this.selectedProjectId !== null;
    }

    get canShowFilters() {
        return this.isRecordSelected && this.showFilters;
    }

    get boardLayoutClass() {
        return this.canShowFilters
            ? 'slds-size_1-of-1 slds-large-size_9-of-12'
            : 'slds-size_1-of-1';
    }


    updateStageCountsFrom(records) {
        //console.log('updateStageCountsFrom called start');
        //console.log('records --> ' + JSON.stringify(records));
        if (this.pickVals != undefined) {
            const statusCountMap = records.reduce((acc, rec) => {
                const status = rec.Status;
                acc[status] = (acc[status] || 0) + 1;
                return acc;
            }, {});

            this.workItemStagePickVals = this.pickVals.map(stage => {
                const count = statusCountMap[stage] || 0;
                return {
                    stage,
                    title: `${stage} (${count})`,
                    count,
                    sortIcon: "utility:arrowup",
                    sortDirection: "asc"
                };
            });

            //console.log('updateStageCountsFrom called');
            //console.log('workItemStagePickVals --> ' + JSON.stringify(this.workItemStagePickVals));

            this.clearWorkItemsIfNoCount(); // If applicable
        }
    }

    @track sortOptions = [];
    @track selectedSortField = 'Work Item Name';
    @track sortDirection = 'asc';

    handleSortChange(event) {
        //console.log('handleSortChange called');
        this.selectedSortField = event.detail.value;
        //console.log('selectedSortField', this.selectedSortField);

    }

    handleSort(event){
        let stage = event.currentTarget.dataset.stage;
        //console.log('handleSort called');
        //console.log('stage', stage);

        //this.sortBy = event.detail.sortBy;
        //this.sortDirection = event.detail.sortDirection;

        this.workItemStagePickVals = this.workItemStagePickVals.map(col => {
            if (col.stage === stage) {
                const newDirection = col.sortDirection === 'asc' ? 'desc' : 'asc';
                const newIcon = newDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
                this.sortDirection = newDirection;
                return { ...col, sortDirection: newDirection, sortIcon: newIcon };
           }
            return col;
        });

        // console.log('event target -> ' , event.target)
        // console.log('event detail -> ' , event.detail)
        // console.log('event detail sortBy -> ' + event.detail.sortBy)
        // console.log('event detail sortDirection -> ' + event.detail.sortDirection)
        //console.log('records -> ' + JSON.stringify(this.workItemRecords));
        //console.log('selectedSortField --> ' + this.selectedSortField);

        let field = this.selectedSortField;
        let direction = this.sortDirection;
        //let direction = 'asc';

        this.workItemRecords = [...this.workItemRecords].sort((a, b) => {
            let valA = a[field] ? a[field].toString().toLowerCase() : '';
            let valB = b[field] ? b[field].toString().toLowerCase() : '';

            // Handle numbers vs strings
            if(!isNaN(valA) && !isNaN(valB)) {
                valA = Number(valA);
                valB = Number(valB);
            }

            if (valA > valB) return direction === 'asc' ? 1 : -1;
            if (valA < valB) return direction === 'asc' ? -1 : 1;
            return 0;
        });
        //console.log('records sorted -> ' + JSON.stringify(this.workItemRecords));

    }

    handleSubmit(event) {
        //console.log('handleSubmit');
        const allFields = [...this.template.querySelectorAll('lightning-input-field')];
        const isValid = allFields.reduce((validSoFar, field) => {
            field.reportValidity();
            return validSoFar && field.checkValidity();
        }, true);

        if (isValid) {
            this.template.querySelector('lightning-record-edit-form').submit();
        }
    }



    handleError(event) {
        console.log('handle Error');
        const error = event.detail;
        // You can show toast or log errors
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error creating Work Item',
                message: error.body ? error.body.message : 'Unknown error',
                variant: 'error',
            })
        );
    }



   @track isLoadingWorkItem = false;

   handleProjectWorkItemRefresh(event){
        //console.log('handleProjectWorkItemRefresh start');
        this.beforeRefreshRecords = this.workItemRecords;
        this.isLoadingWorkItem = true;
        refreshApex(this.workItemsWireResult)
        .then(() => {
            //console.log('Data refreshed successfully', JSON.stringify(this.workItemRecords));
            const children = this.template.querySelectorAll('c-drag-and-drop-list');
            children.forEach(child => child.updateRecordsData(this.workItemRecords));
            this.isLoadingWorkItem = false;
        })
        .catch(error => {
            console.error('Error refreshing:', error);
        });
        setTimeout(() => {
            console.log('spinner start');
            //this.isLoadingWorkItem = false;
        }, 2000);
        /*refreshApex(this.workItemsWireResult)
        .then(() => {
            console.log('Data refreshed successfully');
        })
        .catch(error => {
            console.error('Error refreshing:', error);
        })
        .finally(() => {
            this.isLoadingWorkItem = false;
            console.log('spinner stop');
        });*/
       // console.log('handleProjectWorkItemRefresh end');
   }
  //added on 29/10/25
  /* async handleProjectWorkItemRefresh() {
         this.isLoadingWorkItem = true;

        try {
           // window.location.reload();
            await refreshApex(this.workItemsWireResult);

            //this.applyRecordTypeFilter();
            this.triggerHandleActive();
           
        
        } catch (error) {
            console.error('Refresh failed', error);
        } finally {
            this.isLoadingWorkItem = false;
        }
    }

    applyRecordTypeFilter() {
         if (!this.activeRecordTypeId) return;
         console.log('activeRecordTypeId --> ' + this.activeRecordTypeId);
         console.log('allWorkItemRecords --> ' + this.allWorkItemRecords.length);
        this.workItemRecords = this.allWorkItemRecords.filter(item => {
            return item["Record Type ID"]?.Id === this.activeRecordTypeId;
        });
           
    }

*/

  //added on 29/10/25

   handleFilterList(event) {
        if(this.showFilters === true){
            this.showFilters = false;
        }else if(this.showFilters === false){
            this.showFilters = true;
        }
   }

   async handleFilterClear(){
        try {

            // Combine all filters into one JSON object
            this.isLoadingWorkItem = true;
            this.selectedSearchPicklistValue = "All";
            this.searchTerm = "";
            this.selectedRadioValue = "All Work Items";
            this.checkedAllRadioFilter = true;
            this.checkedMyRadioFilter = false;
            this.filtersJsonData = {
                "searchIn": this.selectedSearchPicklistValue,
                "searchText": this.searchTerm,
                "workItems": this.selectedRadioValue
            };

            // Example: convert your filter data to JSON
            const filterJson = JSON.stringify(this.filtersJsonData);

            await saveUserFilterSetting({ filterJson });
            //console.log('Filters saved successfully');
            setTimeout(() => {
                this.isLoadingWorkItem = false;
            }, 2000);
            this.filterData(); // or this.searchData(); for server-side
        } catch (error) {
            console.error('Error saving filters: ', error);
        }
   }

   async handleFilterSave() {

        const searchInput = this.template.querySelector('[data-id="searchInput"]');

        // Check validity
        if (!searchInput.checkValidity()) {
            searchInput.reportValidity();  // Shows validation error on UI
            return; // stop execution if invalid
        }
        
        
        try {

            // Combine all filters into one JSON object
            this.isLoadingWorkItem = true;
            this.filtersJsonData = {
                "searchIn": this.selectedSearchPicklistValue,
                "searchText": this.searchTerm,
                "workItems": this.selectedRadioValue
            };

            // Example: convert your filter data to JSON
            const filterJson = JSON.stringify(this.filtersJsonData);

            await saveUserFilterSetting({ filterJson });
            //console.log('Filters saved successfully');
            setTimeout(() => {
                this.isLoadingWorkItem = false;
            }, 2000);
        } catch (error) {
            console.error('Error saving filters: ', error);
        }
    }

}

function transformData(data, workItemFieldsName) {


    const edges = data.uiapi.query.Jpeto__Work_Item__c.edges;


    // Transform edges to flat objects with dynamic field extraction
    const transformedData = edges.map(({ node }, index) => {
        // Create a lookup map from apiName to label for fast access
        const fieldLabelMap = {};
        workItemFieldsName.forEach(f => {
            fieldLabelMap[f.apiName] = f.label;
        });


        const flatRecord = {};


        for (const field in node) {

            try {
                const rawValue = node[field];

                const value = rawValue && typeof rawValue === 'object' && 'value' in rawValue
                    ? rawValue.value
                    : rawValue;

                // Get the label for this API name
                const label = fieldLabelMap[field] || field; // fallback to API name if no label found
                flatRecord[label] = value;

            } catch (err) {
                console.error(`Error processing field "${field}":`, err);
            }
        }


        return flatRecord;
    });


    return transformedData;
}