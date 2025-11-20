/**
 * Created by vinay on 22-01-2024.
 */

import { LightningElement ,track, wire } from 'lwc';
import getUniquePayPeriods from '@salesforce/apex/TimesheetQueryController.getUniquePayPeriods';
import aggregate from '@salesforce/apex/TimesheetQueryController.aggregate';
import { getListUi } from 'lightning/uiListApi';
export default class UserHoursTable extends LightningElement {
    @track selectedValue;
    @track selectedCurrentWeek;
    @track weekOptions = [];
    @track options = [];
    @track dayQueryResultMonday = [];
    @track dayQueryResultTuesday = [];
    @track dayQueryResultWednesday = [];
    @track dayQueryResultThursday = [];
    @track dayQueryResultFriday = [];
    @track dayQueryResultSaturday = [];
    @track dayQueryResultSunday = [];
    @track dayQueryResultPayPeriod = [];
    @track sortBy;
    @track sortDirection;
    @track dynamicURL;
    @track viewALlURL;
    @track allListViewId;
    @wire(getListUi, { objectApiName: 'Jpetto__Timesheet__c' })
    wiredListViews({ error, data }) {
        if (data) {
            const allListView = data.lists.find(view => view.apiName == 'All');

            //const allListView = data.listViews.records.find(view => view.fields.label.value === 'All');

            if (allListView) {
                this.allListViewId = allListView.id;
                this.getURL();
                this.viewALlURL = this.dynamicURL + '/lightning/o/Jpetto__Timesheet__c/list?filterName='+this.allListViewId;
                // Perform actions with the All List View ID as needed
            } else {
                console.warn('All list view not found.');
            }
        } else if (error) {
            console.log('error');
            // Handle error
        }
    }
    @track columns = [
    { label: 'User', fieldName: 'recordLink', type: 'url', sortable: true, typeAttributes: { label: { fieldName: 'user' }, target: '_blank' }  },
    { label: 'Total Entries', fieldName: 'totalEntries', type: 'number', sortable: true, cellAttributes: { class: { fieldName: 'TotalEntriesClass' } } },
    { label: 'Total Hours', fieldName: 'totalHours', type: 'number', sortable: true,  cellAttributes: { class: { fieldName: 'TotalHoursClass' } }},
    { label: 'Billable Hours', fieldName: 'billableHours', type: 'number', sortable: true, cellAttributes: { class: { fieldName: 'BillableHoursClass' } }},
    { label: 'Non-Billable Hours', fieldName: 'nonBillableHours', type: 'number', sortable: true, cellAttributes: { class: { fieldName: 'NonBillableHoursClass' } }},
    { label: 'Status', fieldName: 'status', type: 'text', sortable: true }
    ];
    @track weekendcolumns = [
    { label: 'User', fieldName: 'user', type: 'text', sortable: true, typeAttributes: { label: { fieldName: 'User' }, target: '_blank' }  },
    { label: 'Total Entries', fieldName: 'totalEntries', type: 'number', sortable: true },
    { label: 'Total Hours', fieldName: 'totalHours', type: 'number', sortable: true},
    { label: 'Billable Hours', fieldName: 'billableHours', type: 'number', sortable: true},
    { label: 'Non-Billable Hours', fieldName: 'nonBillableHours', type: 'number', sortable: true},
    { label: 'Status', fieldName: 'status', type: 'text', sortable: true }
    ];


    /*--------------------------------------------------------------------------------------------------------------------------------------*/
    getPayPeriods() {
        getUniquePayPeriods()
            .then(result => {
                this.options = result.map(period => ({ label: period, value: period }));
                if (result.length > 0) {
                    this.selectedValue = result[0];
                    const startDayOfWeek = 1;
                        try{
                        // Extract start and end date strings
                        const [startDateString, endDateString] = result[0].split(' - ');
                        // Convert date strings to Date objects
                        const startDate = new Date(startDateString);
                        const endDate = new Date(endDateString);
                        console.log('ERROR2 : ');
                        // Calculate the difference in milliseconds
                        const timeDifference = endDate - startDate;
                        console.log('ERROR3 : ');
                        // Convert milliseconds to days
                        const daysDifference = timeDifference / (1000 * 60 * 60 * 24);
                        console.log('ERROR4 : ');
                        var weekOptions = [];
                        if(daysDifference > 7){
                            const weeks = Math.floor(daysDifference / 7);
                            const remainingDays = daysDifference % 7;
                            console.log('ERROR5 : ', weeks);
                            for (let i = 0; i < weeks; i++) {
                                console.log('ERROR6 : ');
                                const startOfWeek = new Date(startDate.getTime() + (i * 7 + (startDayOfWeek - startDate.getDay())) * 24 * 60 * 60 * 1000);  console.log('ERROR6.1 : ');
                                const endOfWeek = new Date(startOfWeek.getTime() + 6 * 24 * 60 * 60 * 1000); console.log('ERROR6.2 : ');
                                weekOptions.push(startOfWeek.toLocaleDateString() +' - '+ endOfWeek.toLocaleDateString());
                                console.log('ERROR7 : ');
                            }
                            console.log('ERROR8 : ');
                              // If there are remaining days, add them as a separate range
                            if (remainingDays > 0) {
                                console.log('ERROR9 : ');
                                const startOfRemainingDays = new Date(endDate.getTime() - remainingDays * 24 * 60 * 60 * 1000);
                                weekOptions.push(startOfRemainingDays.toLocaleDateString()+' - '+endDate.toLocaleDateString());
                                console.log('ERROR10 : ');
                            }

                        }else{
                            weekOptions.push(result[0]);
                        }
                        this.weekOptions = weekOptions.map(period => ({ label: period, value: period }));
                        this.selectedCurrentWeek = this.weekOptions[0].value;
                        console.log('this.weekOptions  ::::: ', JSON.stringify(this.weekOptions));
                        }catch (error) {
                            console.log('ERROR : ', JSON.stringify(error));
                        }
                    console.log('payPeriod ::: ', JSON.stringify(result));
                    this.callGetDayQuery();
                }
            })
            .catch(error => {
                console.error(error);
            });
       }
    /*--------------------------------------------------------------------------------------------------------------------------------------*/
    callGetDayQuery() {
        this.queryDay('Monday');
        this.queryDay('Tuesday');
        this.queryDay('Wednesday');
        this.queryDay('Thursday');
       this.queryDay('Friday');
        this.queryDay('Saturday');
        this.queryDay('Sunday');
        this.queryDay('PayPeriod');
        }
    /*--------------------------------------------------------------------------------------------------------------------------------------*/
    queryDay(dayOfWeek) {
        const payPeriod = this.selectedValue;
        const dateRange = this.selectedCurrentWeek;
        aggregate({ dayOfWeek, payPeriod, dateRange })
            .then(result => {
                const parsedResult = JSON.parse(result);
                this['dayQueryResult' + dayOfWeek] = parsedResult.map(record => {
                    record.TotalHoursClass = record.totalHours === 0 ? 'slds-text-color_error' : '';
                    record.BillableHoursClass = record.billableHours === 0 ? 'slds-text-color_error' : '';
                    record.NonBillableHoursClass = record.nonBillableHours === 0 ? 'slds-text-color_error' : '';
                    record.TotalEntriesClass = record.totalEntries === 0 ? 'slds-text-color_error' : '';
                    this.getURL();
                    record.recordLink = this.dynamicURL+'/' + record.id; //'https://jpettopackagingorg-dev-ed.develop.lightning.force.com/' + record.id;
                    return record;
                });
               //console.log('callGetDayQuery result:', JSON.stringify(this['dayQueryResult' + dayOfWeek]));
                //console.log('result:', JSON.stringify(result));
            })
            .catch(error => {
                console.error('callGetDayQuery error:', error);
                console.error('Error stack trace:', error.stack); // Log the error stack trace
            });
    }
    /*--------------------------------------------------------------------------------------------------------------------------------------*/
    connectedCallback() {
            this.getPayPeriods();
            //this.callGetDayQuery();
            //this.getURL();
            //this.viewALlURL = this.dynamicURL + 'lightning/o/Jpetto__Timesheet__c/'
        }
    /*--------------------------------------------------------------------------------------------------------------------------------------*/
    handleSelectionChange(event) {
            this.selectedValue = event.detail.value;
            const startDayOfWeek = 1;
            try{
                // Extract start and end date strings
                const [startDateString, endDateString] = this.selectedValue.split(' - ');
                // Convert date strings to Date objects
                const startDate = new Date(startDateString);
                const endDate = new Date(endDateString);
                // Calculate the difference in milliseconds
                const timeDifference = endDate - startDate;
                // Convert milliseconds to days
                const daysDifference = timeDifference / (1000 * 60 * 60 * 24);
                var weekOptions = [];
                if(daysDifference > 7){
                    const weeks = Math.floor(daysDifference / 7);
                    const remainingDays = daysDifference % 7;
                    for (let i = 0; i < weeks; i++) {
                        const startOfWeek = new Date(startDate.getTime() + (i * 7 + (startDayOfWeek - startDate.getDay())) * 24 * 60 * 60 * 1000);
                        const endOfWeek = new Date(startOfWeek.getTime() + 6 * 24 * 60 * 60 * 1000);
                        weekOptions.push(startOfWeek.toLocaleDateString() +' - '+ endOfWeek.toLocaleDateString());
                    }
                      // If there are remaining days, add them as a separate range
                    if (remainingDays > 0) {
                        const startOfRemainingDays = new Date(endDate.getTime() - remainingDays * 24 * 60 * 60 * 1000);
                        weekOptions.push(startOfRemainingDays.toLocaleDateString()+' - '+endDate.toLocaleDateString());

                    }

                }else{
                    weekOptions.push(this.selectedValue);
                }
                this.weekOptions = weekOptions.map(period => ({ label: period, value: period }));
                this.selectedCurrentWeek = this.weekOptions[0].value;
               // console.log('this.weekOptions  ::::: ', JSON.stringify(this.weekOptions));
            }catch (error) {
                console.log('ERROR : ', JSON.stringify(error));
            }
            //console.log('this.selectedValue',this.selectedValue);
            this.callGetDayQuery();
        }

    /*--------------------------------------------------------------------------------------------------------------------------------------*/
    doSortingMonday(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData( 'Monday',this.sortBy, this.sortDirection);
    }

    doSortingTuesday(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData('Tuesday', this.sortBy, this.sortDirection);
    }

    doSortingWednesday(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData('Wednesday', this.sortBy, this.sortDirection);
    }

    doSortingThursday(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData('Thursday', this.sortBy, this.sortDirection);
    }
    doSortingFriday(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData('Friday', this.sortBy, this.sortDirection);
    }

    doSortingSaturday(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData('Saturday', this.sortBy, this.sortDirection);
    }
    doSortingSunday(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData('Sunday', this.sortBy, this.sortDirection);
    }

    doSortingPayPeriod(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData('PayPeriod', this.sortBy, this.sortDirection);
    }
    /*--------------------------------------------------------------------------------------------------------------------------------------*/
    sortData(dayOfWeek, fieldname, direction) {
        let parseData = JSON.parse(JSON.stringify(this['dayQueryResult' + dayOfWeek]));
        //console.log('parseData',parseData);
        let keyValue = (a) => {
            return a[fieldname];
        };
        let isReverse = direction === 'asc' ? 1: -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        this['dayQueryResult' + dayOfWeek] = parseData;
    }
    /*--------------------------------------------------------------------------------------------------------------------------------------*/
    getURL(){
        // Get the current URL
        var currentURL = window.location.href;

        // Create a URL object based on the current URL
        var urlObject = new URL(currentURL);

        // Get the Salesforce base URL (remove the path and query parameters)
        var salesforceBaseURL = urlObject.origin;


        // Log the modified URL to the console (optional)
        //console.log('Modified URL:', salesforceBaseURL);
        this.dynamicURL = salesforceBaseURL;
    }
    /*---------------------------------------------------------------------------------------------------------------------------------------*/
    handleSelectionWeekChange(event){
        this.selectedCurrentWeek = event.detail.value;
        this.callGetDayQuery();
    }
}