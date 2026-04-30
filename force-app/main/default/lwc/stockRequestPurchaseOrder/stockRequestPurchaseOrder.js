import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getStockRequestDetails from '@salesforce/apex/StockRequestPOController.getStockRequestDetails';
import getBranchOptions from '@salesforce/apex/StockRequestPOController.getBranchOptions';
import searchVendorAccounts from '@salesforce/apex/StockRequestPOController.searchVendorAccounts';
import createPurchaseOrderFromItems from '@salesforce/apex/StockRequestPOController.createPurchaseOrderFromItems';

const PURCHASE_ORDER_OBJECT = 'Purchase_Order__c';
const SEARCH_DEBOUNCE_MS = 300;

export default class StockRequestPurchaseOrder extends NavigationMixin(LightningElement) {
    @api recordId;

    @track showModal = false;
    @track stockRequest;
    @track items = [];
    @track isLoading = false;
    @track isSubmitting = false;

    @track branchOptions = [];
    @track selectedBranch = '';

    @track vendorSearchTerm = '';
    @track vendorResults = [];
    @track selectedVendorId = null;
    @track selectedVendorName = '';
    @track showVendorResults = false;
    @track vendorSearching = false;
    @track vendorNoResults = false;

    _vendorSearchTimer;

    @wire(getBranchOptions)
    wiredBranches({ data, error }) {
        if (data) {
            this.branchOptions = data.map(d => ({ label: d.label, value: d.value }));
        } else if (error) {
            this.toast('Error', this.extractError(error), 'error');
        }
    }

    handleOpen() {
        this.showModal = true;
        this.loadDetails();
    }

    handleClose() {
        this.showModal = false;
        this.resetSelections();
    }

    resetSelections() {
        this.selectedBranch = '';
        this.selectedVendorId = null;
        this.selectedVendorName = '';
        this.vendorSearchTerm = '';
        this.vendorResults = [];
        this.showVendorResults = false;
        this.vendorNoResults = false;
    }

    loadDetails() {
        this.isLoading = true;
        getStockRequestDetails({ stockRequestId: this.recordId })
            .then(data => {
                this.stockRequest = data.stockRequest;
                this.items = (data.items || []).map(i => ({
                    ...i,
                    selected: true,
                    price: null,
                    lineTotal: 0
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

    handlePriceChange(event) {
        const itemId = event.currentTarget.dataset.id;
        const value = event.target.value;
        const price = value === '' ? null : Number(value);
        this.items = this.items.map(i => {
            if (i.id !== itemId) return i;
            const qty = Number(i.quantity) || 0;
            const p = price == null ? 0 : price;
            return { ...i, price, lineTotal: qty * p };
        });
    }

    handleBranchChange(event) {
        this.selectedBranch = event.detail.value;
    }

    handleVendorInput(event) {
        const term = event.target.value;
        const isCleared = term === '';
        this.vendorSearchTerm = term;
        if (isCleared) {
            this.selectedVendorId = null;
            this.selectedVendorName = '';
        }
        this.vendorSearching = !isCleared;
        this.showVendorResults = !isCleared;
        this.vendorNoResults = false;

        if (this._vendorSearchTimer) {
            clearTimeout(this._vendorSearchTimer);
        }
        if (isCleared) return;

        this._vendorSearchTimer = setTimeout(() => {
            searchVendorAccounts({ searchTerm: term })
                .then(results => {
                    this.vendorResults = results || [];
                    this.vendorSearching = false;
                    this.vendorNoResults = this.vendorResults.length === 0;
                    this.showVendorResults = true;
                })
                .catch(error => {
                    this.vendorResults = [];
                    this.vendorSearching = false;
                    this.vendorNoResults = true;
                    this.toast('Vendor search failed', this.extractError(error), 'error');
                });
        }, SEARCH_DEBOUNCE_MS);
    }

    handleVendorFocus() {
        if (this.vendorResults.length) {
            this.showVendorResults = true;
        }
    }

    handleVendorBlur() {
        setTimeout(() => {
            this.showVendorResults = false;
        }, 150);
    }

    selectVendor(event) {
        if (event && event.preventDefault) event.preventDefault();
        let el = event.currentTarget;
        if (!el || !el.dataset || !el.dataset.id) {
            el = event.target && event.target.closest ? event.target.closest('[data-id]') : null;
        }
        if (!el || !el.dataset || !el.dataset.id) return;
        this.selectedVendorId = el.dataset.id;
        this.selectedVendorName = el.dataset.name;
        this.vendorSearchTerm = el.dataset.name;
        this.vendorResults = [];
        this.showVendorResults = false;
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

    get totalAmount() {
        return this.items
            .filter(i => i.selected)
            .reduce((sum, i) => {
                const qty = Number(i.quantity) || 0;
                const price = Number(i.price) || 0;
                return sum + qty * price;
            }, 0);
    }

    get formattedTotalAmount() {
        return this.totalAmount.toFixed(2);
    }

    get confirmDisabled() {
        return (
            this.isSubmitting ||
            this.selectedCount === 0 ||
            !this.selectedBranch
        );
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

    get vendorDropdownClass() {
        return this.showVendorResults
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    handleConfirm() {
        const selected = this.items.filter(i => i.selected);
        if (selected.length === 0) {
            this.toast('No items selected', 'Select at least one item to create a Purchase Order.', 'warning');
            return;
        }
        if (!this.selectedBranch) {
            this.toast('Branch required', 'Please select a Branch.', 'warning');
            return;
        }

        const payload = selected.map(i => ({
            id: i.id,
            price: i.price == null ? 0 : Number(i.price)
        }));

        this.isSubmitting = true;
        createPurchaseOrderFromItems({
            stockRequestId: this.recordId,
            branch: this.selectedBranch,
            vendorId: this.selectedVendorId,
            totalAmount: this.totalAmount,
            itemsJson: JSON.stringify(payload)
        })
            .then(poId => {
                this.toast('Success', 'Purchase Order created successfully.', 'success');
                this.showModal = false;
                this.resetSelections();
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
