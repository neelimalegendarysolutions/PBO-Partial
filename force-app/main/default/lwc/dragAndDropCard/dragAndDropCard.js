import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecordCreateDefaults } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getObjectApiName from '@salesforce/apex/WorkItemControllerPMT.getObjectApiName';

export default class DragAndDropCard extends NavigationMixin(LightningElement) {
    @api stage;
    @api record;
    @track transformedRecord;
    @api sprintId;
    @api isCommunity = false;
    @api customRedirectLink;

    @api enableActionMenu;
    showLogHours = false;
    @track sections = [];
    timesheetEntryObjectApiName = 'Jpeto__Timesheet_Entry__c';
    showConfirmation = false;
    action;
    closingComments = '';
    @api allPickValues;
    @api teamUsers;
    @track selectedAssignee = '';
    @track showAssignAssignModal = false;
    @track isMenuOpen = false;
    @track _refreshFlag = false;
    
    @api
    refreshRecord(newRecord) {
        this.record = undefined;
        
        this.record = { ...newRecord }; // reassign new object to trigger re-render
        this.transformRecordFields();
        this._refreshFlag = !this._refreshFlag;
    }

    portalSubmenuElement = null;
    _hoveringSubmenu = false;

    get recordId() {
        return this.record?.Id || null;
    }

    get objectApiName() {
        return this.record?.attributes?.apiName || 'Jpeto__Work_Item__c';
    }

    @track hoverObjectApiName = '';
    @track showPreview = false;
    @track hoveredRecordId;
    @track popupStyle = '';

    hoverTimeout;

    isPreviewVisible(recordId) {
        return this.showPreview && this.hoveredRecordId === recordId;
    }

    // Called on mouse enter for a record wrapper
    /*async handleMouseEnter(event) {
        clearTimeout(this.hoverTimeout);
        const rect = event.target.getBoundingClientRect();

        // 👇 Show beside the hovered field
        let top = rect.top + window.scrollY;
        let left = rect.right + window.scrollX + 10;

        const popupWidth = 340;
        const screenWidth = window.innerWidth;
        if (left + popupWidth > screenWidth) {
            left = rect.left + window.scrollX - popupWidth - 10;
        }

        const recordId = event.currentTarget.dataset.id;
        this.hoveredRecordId = recordId;

        await getObjectApiName({ recordId: this.hoveredRecordId })
        .then(result => {
            this.hoverObjectApiName = result;
            this.showPreview = true;
            this.popupStyle = `position:fixed; top:${top}px; left:${left}px; z-index:9999;`;
        })
        .catch(error => {
            this.hoverObjectApiName = undefined;
            console.error('Error fetching object API name:', error);
        });
    }*/

    async handleMouseEnter(event) {
        clearTimeout(this.hoverTimeout);
        const rect = event.target.getBoundingClientRect();

        const popupWidth = 340;
        const popupHeight = 320; // same as max-height
        const screenWidth = window.innerWidth;
        const screenHeight = window.innerHeight;

        let top = rect.top + window.scrollY;
        let left = rect.right + window.scrollX + 10;

        // 👇 Flip horizontally if there's not enough space on the right
        if (left + popupWidth > screenWidth) {
            left = rect.left + window.scrollX - popupWidth - 10;
        }

        // 👇 Shift upward if the popup goes below screen
        if (top + popupHeight > screenHeight) {
            top = screenHeight - popupHeight - 20;
        }

        const recordId = event.currentTarget.dataset.id;
        this.hoveredRecordId = recordId;

        try {
            const result = await getObjectApiName({ recordId: this.hoveredRecordId });
            this.hoverObjectApiName = result;
            this.showPreview = true;
            this.popupStyle = `position:fixed; top:${top}px; left:${left}px; z-index:9999;`;
        } catch (error) {
            console.error('Error fetching object API name:', error);
        }
    }


    // Called on mouse leave for a record wrapper
    handleMouseLeave() {
        //this.showPreview = false;
        //this.hoveredRecordId = null;

         this.hoverTimeout = setTimeout(() => {
            this.showPreview = false;
        }, 250); // small delay to allow moving into popup
    }

    keepOpen() {
        clearTimeout(this.hoverTimeout);
    }

    closePreview() {
        this.showPreview = false;
    }


    // Return records decorated with previewVisible flag for template rendering
    get processedFields() {
        return this.transformedRecord.fields.map(rec => {
            return {
                ...rec,
                previewVisible: this.showPreview && rec.id === this.hoveredRecordId
            };
        });
    }

    
    connectedCallback() {
        document.addEventListener('click', this.handleOutsideClick);
        this.transformRecordFields();

       
    }

   

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
        this.removePortalSubmenu();

               
    }

    transformRecordFields() {
        const fields = [];
        for (const key in this.record) {
            if (!['Id','Work Item Name','Record Type ID','Sprint'].includes(key)) {
                const rawValue = this.record[key];
                const plainValue = rawValue ? rawValue.toString().replace(/<[^>]*>/g, '') : '';
                //fields.push({ label: key, value: plainValue });

                if (typeof rawValue === 'object' && rawValue !== null && !Array.isArray(rawValue)) {
                    //this.currentTargetObjectRecordId = rawValue.Id;
                    //fields.push({ label: key, value: rawValue.Name, url: `/lightning/r/Jpeto__Work_Item__c/${rawValue.Id}/view`});
                    fields.push({ label: key, value: rawValue.Name, url: `/${rawValue.Id}`, id: rawValue.Id});
                }else{
                    fields.push({ label: key, value: plainValue, url: '', id: ''});
                }
            }
        }
        this.transformedRecord = {
            Id: this.record.Id,
            Name: this.record['Work Item Name'],
            recordUrl: this.isCommunity && this.customRedirectLink ? `${this.customRedirectLink}/${this.record.Id}` : `/lightning/r/Jpeto__Work_Item__c/${this.record.Id}/view`,
            fields: fields
        };
    }

    get isSameStage() {
        return this.stage === this.record.Status;
    }

    get bgClass() {
        return this.record.Sprint ? 'slds-item slds-var-m-around_small' : 'slds-item slds-var-m-around_small yellow-bg';
    }

    get columns() {
        return this.allPickValues
            .filter(val => val !== this.stage)
            .map(val => ({ label: val, value: val }));
    }

    toggleMenu(event) {
        event.stopPropagation();
        this.isMenuOpen = !this.isMenuOpen;
    }

    handleClickedLogHours() {
        this.showLogHours = true;
        setTimeout(() => {
            
        const fields = this.template.querySelectorAll('lightning-input-field');
        fields.forEach(field => {
            if (field.fieldName === 'Jpeto__Work_Item__c') {
                field.value = this.transformedRecord.Id;
            }
        })
        }, 100);
    }

    handleCancel() {
        this.showLogHours = false;
    }

    // ✅ Manual submit handler
    handleSaveClick() {
        const form = this.template.querySelector('[data-id="timesheetForm"]');
        if (form) {
            form.submit();
        } else {
            console.error('Form not found!');
        }
    }

    handleSuccess() {
        this.showLogHours = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Timesheet entry created successfully!',
                variant: 'success'
            })
        );
        this.dispatchEvent(new CustomEvent('loghours', {
            detail: { },
            bubbles: true,
            composed: true
        }));
        console.log('event dispatched');
    }

    handleError(event) {
        console.error('Error saving record:', event.detail);
        let errorMessage = event.detail.message;
        if(event.detail.detail){
            errorMessage = errorMessage+' error detail: '+event.detail.detail;
        }
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                //message: 'Unable to save record. Please check required fields.',
                message: errorMessage,
                variant: 'error'
            })
        );
    }

    @wire(getRecordCreateDefaults, { objectApiName: '$timesheetEntryObjectApiName' })
    wiredDefaults({ data, error }) {
        if (data) {
            this.sections = data.layout.sections
                .map(section => {
                    const layoutRows = section.layoutRows
                        .map(row => {
                            const layoutItems = row.layoutItems
                                .map(item => {
                                    const layoutComponents = (item.layoutComponents || [])
                                        .filter(comp => comp.apiName !== 'Name') // ✅ Filter out Name
                                        .map(comp => ({
                                            apiName: comp.apiName
                                        }));
                                    return {
                                        ...item,
                                        layoutComponents
                                    };
                                })
                                // ✅ Filter out layout items that have no fields left
                                .filter(item => item.layoutComponents.length > 0);

                            return {
                                ...row,
                                layoutItems
                            };
                        })
                        // ✅ Filter out rows that now have no visible items
                        .filter(row => row.layoutItems.length > 0);

                    return {
                        id: section.id,
                        heading: section.heading,
                        layoutRows
                    };
                })
                // ✅ Filter out sections with no visible rows
                .filter(section => section.layoutRows.length > 0);

        } else if (error) {
            console.error('Error fetching layout metadata', error);
        }
    }


    handleClose(event) {
        event.stopPropagation();
        this.isMenuOpen = false;
        this.action = 'close';
        this.showConfirmation = true;
    }

    handleCommentsChange(event) {
        this.closingComments = event.target.value;
    }

    handleConfirm() {
        const comments = this.template.querySelector('lightning-textarea');
        if (!comments.checkValidity()) { comments.reportValidity(); return; }
        this.showConfirmation = false;
        
        this.closeTicket();
    }

    handleCancel() {
        this.showConfirmation = false;
        this.closingComments = '';

        //closing log hours modal box
        this.showLogHours = false;
    }

    closeTicket() {
        this.dispatchEvent(new CustomEvent('closeaction', {
            detail: {
                action: this.action,
                recordId: this.transformedRecord.Id,
                closingComments: this.closingComments
            },
            bubbles: true,
            composed: true
        }));
        this.closingComments = '';
    }

    handleLogHours(event){
        event.stopPropagation();
    }

    handleAssign(event) {
        event.stopPropagation();
        this.isMenuOpen = false;
        this.showAssignAssignModal = true;
    }

    handleAssigneeChange(event) {
        this.selectedAssignee = event.detail.value;
    }

    handleAssignCancel() {
        this.showAssignAssignModal = false;
        this.selectedAssignee = '';
    }

    handleAssignConfirm(event) {
        event.stopPropagation();
        const combobox = this.template.querySelector('lightning-combobox');
        if (!combobox.checkValidity()) { combobox.reportValidity(); return; }

        const selectedUser = this.teamUsers.find(u => u.value === this.selectedAssignee);
        this.dispatchEvent(new CustomEvent('assign', {
            detail: {
                recordId: this.transformedRecord.Id,
                assignee: selectedUser,
                newStage: this.stage
            },
            bubbles: true,
            composed: true
        }));
        this.showAssignAssignModal = false;
        this.selectedAssignee = '';
    }

    handleOutsideClick = (event) => {
        if (!this.template.contains(event.target)) {
            this.isMenuOpen = false;
            this.removePortalSubmenu();
        }
    }

    // Drag events
    itemDragStart() { this.classList.add('dragging'); 
        const event = new CustomEvent('itemdrag', {
            detail: { recordId: this.record.Id, oldStage: this.record.Status, stage: this.stage }
        })
        this.dispatchEvent(event)
    }
    itemDragEnd() { this.classList.remove('dragging'); }
    handleDragOver(evt) { evt.preventDefault(); }

    // Move To submenu hover
    showSubmenu(event) {
        const triggerEl = event.currentTarget;

        // Remove any existing submenu
        this.removePortalSubmenu();

        const ul = document.createElement('ul');
        ul.className = 'portal-submenu';

        // Apply explicit styles for look and feel
        Object.assign(ul.style, {
            position: 'absolute',
            zIndex: '9999',
            background: '#fff',
            border: '1px solid #ddd',
            borderRadius: '0.25rem',
            boxShadow: '0 2px 6px rgba(0,0,0,0.2)',
            minWidth: '150px',
            padding: '4px 0',
            listStyle: 'none'
        });

        // Add submenu items
        this.columns.forEach(col => {
            const li = document.createElement('li');
            li.textContent = col.label;
            li.dataset.col = col.value;

            Object.assign(li.style, {
                padding: '8px 12px',
                cursor: 'pointer',
                whiteSpace: 'nowrap'
            });

            li.onmouseenter = () => li.style.backgroundColor = '#f3f3f3';
            li.onmouseleave = () => li.style.backgroundColor = '#fff';

            li.onclick = (e) => {
                this.handleMoveTo(e);
                this.removePortalSubmenu();
            };

            ul.appendChild(li);
        });

        // Add scrollbar if more than 5 items
        const itemHeight = 32; // Approx height including padding (adjust if needed)
        if (this.columns.length > 5) {
            ul.style.maxHeight = `${itemHeight * 5}px`;
            ul.style.overflowY = 'auto';
        }

        const rect = triggerEl.getBoundingClientRect();
        ul.style.top = `${rect.top + window.scrollY}px`;
        ul.style.left = `${rect.right + window.scrollX}px`;

        document.body.appendChild(ul);              
        this.portalSubmenuElement = ul;

        // Keep submenu open when hovering
        ul.addEventListener('mouseenter', () => this._hoveringSubmenu = true);
        ul.addEventListener('mouseleave', () => { this._hoveringSubmenu = false; this.removePortalSubmenu(); });

        triggerEl.addEventListener('mouseleave', () => {
            setTimeout(() => { if (!this._hoveringSubmenu) this.removePortalSubmenu(); }, 50);
        });
    }

    

    removePortalSubmenu() {
        if (this.portalSubmenuElement) {
            document.body.removeChild(this.portalSubmenuElement);
            this.portalSubmenuElement = null;
            this._hoveringSubmenu = false;
        }
    }

    handleMoveTo(event) {
        event.stopPropagation();
        const newStage = event.currentTarget.dataset.col;
        this.isMenuOpen = false;

        this.dispatchEvent(new CustomEvent('movetostage', {
            detail: {
                recordId: this.transformedRecord.Id,
                oldStage: this.stage,
                newStage: newStage
            },
            bubbles: true,
            composed: true
        }));
    }

    
    

    


}