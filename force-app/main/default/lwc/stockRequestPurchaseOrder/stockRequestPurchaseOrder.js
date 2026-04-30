import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getStockRequestDetails from '@salesforce/apex/StockRequestPOController.getStockRequestDetails';
import createPurchaseOrderFromItems from '@salesforce/apex/StockRequestPOController.createPurchaseOrderFromItems';

const PURCHASE_ORDER_OBJECT = 'Purchase_Order__c';

export default class StockRequestPurchaseOrder extends NavigationMixin(LightningElement) {
    @api recordId;

    @track showModal = false;
    @track stockRequest;
    @track items = [];
    @track isLoading = false;
    @track isSubmitting = false;

    handleOpen() {
        this.showModal = true;
        this.loadDetails();
    }

    handleClose() {
        this.showModal = false;
    }

    loadDetails() {
        this.isLoading = true;
        getStockRequestDetails({ stockRequestId: this.recordId })
            .then(data => {
                this.stockRequest = data.stockRequest;
                this.items = (data.items || []).map(i => ({
                    ...i,
                    selected: true
                }));
            })
            .catch(error => {
                this.toast('Error', this.extractError(error), 'error');
                this.showModal = false;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRowToggle(event) {
        const itemId = event.currentTarget.dataset.id;
        const checked = event.target.checked;
        this.items = this.items.map(i =>
            i.id === itemId ? { ...i, selected: checked } : i
        );
    }

    handleSelectAll(event) {
        const checked = event.target.checked;
        this.items = this.items.map(i => ({ ...i, selected: checked }));
    }

    get allSelected() {
        return this.items.length > 0 && this.items.every(i => i.selected);
    }

    get selectedCount() {
        return this.items.filter(i => i.selected).length;
    }

    get hasItems() {
        return this.items && this.items.length > 0;
    }

    get confirmDisabled() {
        return this.isSubmitting || this.selectedCount === 0;
    }

    get stockRequestName() {
        return this.stockRequest ? this.stockRequest.Name : '';
    }

    get productCategory() {
        return this.stockRequest ? this.stockRequest.Product_Category__c : '';
    }

    get status() {
        return this.stockRequest ? this.stockRequest.Status__c : '';
    }

    get ownerName() {
        return this.stockRequest && this.stockRequest.Owner
            ? this.stockRequest.Owner.Name
            : '';
    }

    handleConfirm() {
        const selectedIds = this.items.filter(i => i.selected).map(i => i.id);
        if (selectedIds.length === 0) {
            this.toast('No items selected', 'Select at least one item to create a Purchase Order.', 'warning');
            return;
        }

        this.isSubmitting = true;
        createPurchaseOrderFromItems({
            stockRequestId: this.recordId,
            selectedItemIds: selectedIds
        })
            .then(poId => {
                this.toast('Success', 'Purchase Order created successfully.', 'success');
                this.showModal = false;
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: poId,
                        objectApiName: PURCHASE_ORDER_OBJECT,
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.toast('Error', this.extractError(error), 'error');
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (!error) return 'Unknown error';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
