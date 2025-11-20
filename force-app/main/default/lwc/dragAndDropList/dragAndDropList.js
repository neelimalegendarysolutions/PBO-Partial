import { LightningElement, api } from 'lwc';

export default class DragAndDropList extends LightningElement {
    @api records=[];
    @api stage;
    @api sprintId;
    @api enableActionMenu = false;
    @api isCommunity = false;
    @api customRedirectLink;

    @api allPickValues;
    oldStage;
    @api teamUsers;

    dragCounter = 0;

    dropTargetRecordId = null;
    dropPosition = null; // 'above' | 'below'
    draggedRecordId = null;

    handleItemDrag(evt) {
        this.oldStage = this.stage;
        this.draggedRecordId = evt.detail.recordId;
        console.log('handleItemDrag called',evt.detail.recordId );
        const event = new CustomEvent('listitemdrag', {
            detail: {
                recordId: evt.detail.recordId,
                oldStage: evt.detail.oldStage,
                stage: evt.detail.stage
            }
        });
        this.dispatchEvent(event);
    }

    @api
    updateRecordsData(updatedValues) {
        this._records = JSON.parse(JSON.stringify(updatedValues));
        this._records.forEach(record => {
            this.updateCard(record);
        });
    }

    updateCard(record) {
    const card = this.template.querySelector(`c-drag-and-drop-card[data-id="${record.Id}"]`);
    if (card) {
        card.refreshRecord(record);
    }
}

    handleDragEnter(event) {
        event.preventDefault();
        this.dragCounter++;
        event.currentTarget.classList.add('drag-over');
    }

    // ✅ Preserving your original guards and cleanup behavior
    handleDragLeave(event) {
        event.preventDefault();

        // Sometimes relatedTarget is null -> means we left the drop zone entirely
        if (!event.currentTarget.contains(event.relatedTarget)) {
            this.dragCounter--;
            if (this.dragCounter == 0) {
                this.dragCounter = 0;
                event.currentTarget.classList.remove('drag-over');
            }
        }
        if (event.currentTarget.contains(event.relatedTarget)) {
            return;
        }
        event.currentTarget.classList.remove('drag-over');
    }

    handleDragOver(event) {
        event.preventDefault(); // required to allow dropping
    }

    handleDrop(event) {
        event.preventDefault();


            this.reorderRecords();

        // Fire event for parent to persist server-side
        const dropEvent = new CustomEvent('itemdrop', {
            detail: {
                stage: this.stage,
                oldStage: this.oldStage,
                draggedRecordId: this.draggedRecordId,
                dropTargetRecordId: this.dropTargetRecordId,
                dropPosition: this.dropPosition
            }
        });
        this.dispatchEvent(dropEvent);

        // Reset visual state
        this.resetHighlight(event.currentTarget);

        // ✅ Preserving your exact cleanup lines
        this.dragCounter = 0;
        const target = event.currentTarget;
        if (target.classList.contains('drag-over')) {
            // eslint-disable-next-line no-console
            console.log('class removing');
            target.classList.remove('drag-over');
            // eslint-disable-next-line no-console
            console.log('class removing');
        }
    }

    // Reorder helper (keeps your variables & behavior)
    reorderRecords() {
        if (!this.draggedRecordId || !this.dropTargetRecordId) return;

        const newRecords = [...this.records];

        const draggedIndex = newRecords.findIndex(
            r => r.Id === this.draggedRecordId
        );
        const targetIndex = newRecords.findIndex(
            r => r.Id === this.dropTargetRecordId
        );

        if (draggedIndex === -1 || targetIndex === -1) {
            return;
        }

        // remove dragged record
        const [draggedRecord] = newRecords.splice(draggedIndex, 1);

        let newIndex = targetIndex;

        if (this.dropPosition === 'below') {
            newIndex = targetIndex + 1;
        }

        // ✅ adjust index if dragged was above target
        if (draggedIndex < targetIndex && this.dropPosition === 'above') {
            newIndex--;
        }
        if (draggedIndex < targetIndex && this.dropPosition === 'below') {
            newIndex--;
        }

        newRecords.splice(newIndex, 0, draggedRecord);

        this.records = newRecords;
    }


    resetHighlight(target) {
        this.dragCounter = 0;
        target.classList.remove('drag-over');
        const items = this.template.querySelectorAll('.drop-item');
        items.forEach(el => el.classList.remove('drop-line-top', 'drop-line-bottom'));
        this.dropTargetRecordId = null;
        this.dropPosition = null;
    }

    handleItemDragOver(event) {
        event.preventDefault();

        const element = event.currentTarget;
        const rect = element.getBoundingClientRect();
        const offsetY = event.clientY - rect.top;

        element.classList.remove('drop-line-top', 'drop-line-bottom');

        if (offsetY < rect.height / 2) {
            element.classList.add('drop-line-top');
            this.dropTargetRecordId = element.dataset.id;
            this.dropPosition = 'above';
        } else {
            element.classList.add('drop-line-bottom');
            this.dropTargetRecordId = element.dataset.id;
            this.dropPosition = 'below';
        }
    }

    handleItemDragLeave(event) {
        event.currentTarget.classList.remove('drop-line-top', 'drop-line-bottom');
    }

    handleItemDrop(event) {
        const element = event.currentTarget;
        element.classList.remove('drop-line-top', 'drop-line-bottom');
    }

    // Extra safety: if a drag ends anywhere, clear visuals
    handleDragEnd() {
        const zones = this.template.querySelectorAll('.dropZone');
        zones.forEach(z => {
            this.dragCounter = 0;
            z.classList.remove('drag-over');
        });
        const items = this.template.querySelectorAll('.drop-item');
        items.forEach(el => el.classList.remove('drop-line-top', 'drop-line-bottom'));
        this.dropTargetRecordId = null;
        this.dropPosition = null;
    }

    handleCloseAction(event){
        const details = event.detail;
        // console.log(' details --> ' + JSON.stringify(details));
        // console.log('action --> ' + event.detail.action)
        // console.log('recordId --> ' + event.detail.recordId)
        // console.log('handleCloseAction called')
        this.dispatchEvent(new CustomEvent('close', {
            detail: {
                action:event.detail.action,   
                recordId: event.detail.recordId,
                closingComments: event.detail.closingComments
            },
            bubbles: true,
            composed: true
        }));
        //console.log('event dispatched');
    }

    handleMoveToStage(event) {
        const details = event.detail;
         console.log(' details --> ' + JSON.stringify(details));
         console.log('recordId --> ' + event.detail.recordId)
         console.log('handleMoveTo called')
        this.dispatchEvent(new CustomEvent('movetostage', {
            detail: { 
                recordId: event.detail.recordId,
                oldStage: event.detail.oldStage,
                newStage: event.detail.newStage
            },
            bubbles: true,
            composed: true
        }));
    }
    
    handleAssign(event) {
        const details = event.detail;
        console.log(' details --> ' + JSON.stringify(details));
        console.log('handleAssign called')
        this.dispatchEvent(new CustomEvent('assign', {
            detail: { 
                recordId: event.detail.recordId,
                assignee: event.detail.assignee,
                newStage: event.detail.newStage
            },
            bubbles: true,
            composed: true
        }));
    }
}