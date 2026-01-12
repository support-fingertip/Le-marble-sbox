import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateDealStage from '@salesforce/apex/DealPathController.updateDealStage';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
//import STAGE_FIELD from '@salesforce/schema/Pending_Purchase__c.Stage__c';
import { refreshApex } from '@salesforce/apex';

const FIELDS = [STAGE_FIELD];

export default class DealPath2 extends NavigationMixin(LightningElement) {
    @api recordId;
    @track currentStep;
    @track selectedStep = '';
    @track showDateModal = false;
    @track expectedDate;
    @track pathOptions = [
        {
            label: 'Purchase Order Placed',
            value: 'Purchase Order Placed',
            name: 'Purchase Order Placed'
        },
        {
            label: 'Order Confirmed',
            value: 'Order Confirmed',
            name: 'Order Confirmed'
        },
        {
            label: 'In Transit',
            value: 'In Transit',
            name: 'In Transit'
        },
        {
            label: 'Arrived',
            value: 'Arrived',
            name: 'Arrived'
        },
        {
            label: 'Delayed',
            value: 'Delayed',
            name: 'Delayed'
        },
        {
            label: 'Item discontinued',
            value: 'Item discontinued',
            name: 'Item discontinued'
        }
    ];

    wiredRecordResult;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord(result) {
        this.wiredRecordResult = result;
        const { error, data } = result;
        if (data) {
            this.currentStep = data.fields.Stage__c.value;
            this.selectedStep = '';
        }
    }

    handleSelect(event) {
        const selectedStage = event.detail.value;
        
        if (selectedStage === 'Delayed') {
            this.showDateModal = true;
            this.selectedStep = selectedStage;
        } else {
            this.updateStage(selectedStage);
        }
    }

    handleDateSubmit() {
        if (!this.expectedDate) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select an expected date',
                    variant: 'error'
                })
            );
            return;
        }
        
        this.updateStage(this.selectedStep);
        this.showDateModal = false;
    }

    handleDateChange(event) {
        this.expectedDate = event.target.value;
    }

    handleCancel() {
        this.showDateModal = false;
        this.expectedDate = null;
        this.selectedStep = '';
    }

    updateStage(stage) {
        updateDealStage({ 
            recordId: this.recordId, 
            stage: stage,
            expectedDate: this.expectedDate
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Stage updated successfully',
                    variant: 'success'
                })
            );
            refreshApex(this.wiredRecordResult);
        })
        .catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }

    handleStepClick(event) {
        const selectedStep = event.target.value;
        this.selectedStep = selectedStep;
    }

    get showMarkComplete() {
        return this.selectedStep && this.selectedStep !== this.currentStep;
    }

    handleMarkComplete() {
        this.handleSelect({ detail: { value: this.selectedStep } });
    }
}