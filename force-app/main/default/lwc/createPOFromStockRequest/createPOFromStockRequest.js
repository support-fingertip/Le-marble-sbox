import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getStockRequestDetails from '@salesforce/apex/StockRequestToPOController.getStockRequestDetails';
import createPurchaseOrder from '@salesforce/apex/StockRequestToPOController.createPurchaseOrder';

export default class CreatePOFromStockRequest extends NavigationMixin(LightningElement) {
    @api recordId;

    showModal = false;
    isLoading = false;
    isSubmitting = false;

    stockRequest;
    @track rows = [];
    wiredResult;

    @wire(getStockRequestDetails, { stockRequestId: '$recordId' })
    wiredDetails(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.stockRequest = data.stockRequest;
            this.rows = (data.items || []).map(item => ({
                id: item.Id,
                name: item.Name,
                productId: item.Product__c,
                productName: item.Product__r ? item.Product__r.Name : '',
                quantity: item.Quantity__c,
                selected: true
            }));
        } else if (error) {
            this.showError('Failed to load stock request details', error);
        }
    }

    handleOpen() {
        this.showModal = true;
        refreshApex(this.wiredResult);
    }

    @api invoke() {
        this.handleOpen();
    }

    handleClose() {
        this.showModal = false;
    }

    handleCheckboxChange(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;
        this.rows = this.rows.map(r => (r.id === id ? { ...r, selected: checked } : r));
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get selectedCount() {
        return this.rows.filter(r => r.selected).length;
    }

    get confirmDisabled() {
        return this.isSubmitting || this.selectedCount === 0;
    }

    get stockRequestName() {
        return this.stockRequest ? this.stockRequest.Name : '';
    }

    get stockRequestCategory() {
        return this.stockRequest ? this.stockRequest.Product_Category__c : '';
    }

    get stockRequestStatus() {
        return this.stockRequest ? this.stockRequest.Status__c : '';
    }

    get stockRequestOwner() {
        return this.stockRequest && this.stockRequest.Owner ? this.stockRequest.Owner.Name : '';
    }

    async handleConfirm() {
        const selectedIds = this.rows.filter(r => r.selected).map(r => r.id);
        if (selectedIds.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No items selected',
                message: 'Please select at least one item to create a purchase order.',
                variant: 'warning'
            }));
            return;
        }
        this.isSubmitting = true;
        try {
            const poId = await createPurchaseOrder({
                stockRequestId: this.recordId,
                selectedItemIds: selectedIds
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Purchase Order created with ' + selectedIds.length + ' item(s).',
                variant: 'success'
            }));
            this.showModal = false;
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: poId,
                    objectApiName: 'Purchase_Order__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showError('Failed to create Purchase Order', error);
        } finally {
            this.isSubmitting = false;
        }
    }

    showError(title, error) {
        const message = (error && error.body && error.body.message)
            ? error.body.message
            : (error && error.message) || 'Unknown error';
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'error'
        }));
    }
}
