import { LightningElement, api } from 'lwc';
import processCaseToWorkItem from '@salesforce/apex/CaseToWorkItemService.processCaseToWorkItem';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from 'lightning/actions';

export default class HeadlessCaseToWorkitem extends LightningElement {
    @api recordId;

    isLoading = true;
    hasError = false;
    hasRun = false; // ⭐ Prevent double execution
    errorMessage = '';
    resultData = null;

    connectedCallback() {
        //code
    
        // Wait until recordId is available
        if (this.recordId && !this.hasRun) {
            this.hasRun = true;
            console.log('Case Record ID:', this.recordId);
           
        }
         this.processCase();
    }

    processCase() {
        console.log('Case Record ID:', this.recordId);
        processCaseToWorkItem({ caseId: this.recordId })
            .then(result => {
                let resultJSON = JSON.parse(result);

                this.isLoading = false;
                this.resultData = resultJSON;

                this.showNotification(
                    'Success!',
                    `Work item ${resultJSON.Work_Item_Name__c} has been successfully created!`,
                    'success',
                    [{
                        url: resultJSON.Work_Item_URL__c,
                        label: 'here'
                    }],
                    'sticky'
                );

                setTimeout(() => this.closeAction(), 3000);
            })
            .catch(error => {
                this.handleError(this.extractErrorMessage(error));
            });
    }

    extractErrorMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred';
    }

    handleError(msg) {
        this.isLoading = false;
        this.hasError = true;
        this.errorMessage = msg;

        this.showNotification('Error!', msg, 'error', null, 'sticky');
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showNotification(title, message, variant, messageData, mode) {
        this.dispatchEvent(new ShowToastEvent({
            title, message, variant, messageData, mode
        }));
    }
}