import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getProductCategories from '@salesforce/apex/StockRequestController.getProductCategories';
import searchProducts from '@salesforce/apex/StockRequestController.searchProducts';
import createStockRequestWithItems from '@salesforce/apex/StockRequestController.createStockRequestWithItems';

const SEARCH_DEBOUNCE_MS = 300;
const STOCK_REQUEST_OBJECT = 'Stock_Request__c';

export default class StockRequestCreator extends NavigationMixin(LightningElement) {

    @track selectedCategory = '';
    @track categoryOptions = [];
    @track items = [];
    @track isLoading = false;

    _rowSeq = 0;
    _searchTimers = {};

    @wire(getProductCategories)
    wiredCategories({ data, error }) {
        if (data) {
            this.categoryOptions = data.map(d => ({ label: d.label, value: d.value }));
        } else if (error) {
            this.toast('Error', this.extractError(error), 'error');
        }
    }

    connectedCallback() {
        // Empty state will prompt the user to pick a category first,
        // then add rows. Auto-adding a row before a category is set
        // triggers the "Select Category" warning toast.
    }

    get hasNoItems() {
        return this.items.length === 0;
    }

    get isAddDisabled() {
        return !this.selectedCategory;
    }

    get getDropdownClass() {
        return 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open';
    }

    handleCategoryChange(event) {
        const wasEmpty = !this.selectedCategory;
        this.selectedCategory = event.detail.value;
        // Clear product selections since category drives the product list
        this.items = this.items.map(row => ({
            ...row,
            productId: null,
            searchTerm: '',
            results: [],
            showResults: false,
            noResults: false,
            searching: false
        }));
        // First time picking a category: seed an empty first row so the
        // user does not have to click Add Row before they can start.
        if (wasEmpty && this.selectedCategory && this.items.length === 0) {
            this._rowSeq += 1;
            this.items = [this.makeRow(`r-${this._rowSeq}`)];
        }
    }

    addRow() {
        if (!this.selectedCategory) {
            this.toast('Select Category', 'Pick a Product Category before adding rows.', 'warning');
            return;
        }
        this._rowSeq += 1;
        this.items = [
            ...this.items,
            this.makeRow(`r-${this._rowSeq}`)
        ];
    }

    makeRow(key) {
        return {
            key,
            productId: null,
            searchTerm: '',
            quantity: null,
            results: [],
            showResults: false,
            noResults: false,
            searching: false
        };
    }

    removeRow(event) {
        const key = event.currentTarget.dataset.key;
        this.items = this.items.filter(r => r.key !== key);
    }

    handleQuantityChange(event) {
        const key = event.currentTarget.dataset.key;
        const value = event.target.value;
        this.items = this.items.map(r =>
            r.key === key ? { ...r, quantity: value === '' ? null : Number(value) } : r
        );
    }

    handleProductFocus(event) {
        const key = event.currentTarget.dataset.key;
        this.items = this.items.map(r =>
            r.key === key && r.results.length ? { ...r, showResults: true } : r
        );
    }

    handleProductBlur(event) {
        const key = event.currentTarget.dataset.key;
        // Delay so a selection click can register before the dropdown closes
        setTimeout(() => {
            this.items = this.items.map(r =>
                r.key === key ? { ...r, showResults: false } : r
            );
        }, 150);
    }

    handleProductInput(event) {
        const key = event.currentTarget.dataset.key;
        const term = event.target.value;
        const isCleared = term === '';

        // Update the row immediately so the input stays responsive.
        // Only clear productId when the user clears the input entirely;
        // typing to refine the search must not wipe an existing selection.
        this.items = this.items.map(r =>
            r.key === key
                ? {
                      ...r,
                      searchTerm: term,
                      productId: isCleared ? null : r.productId,
                      searching: !isCleared,
                      showResults: !isCleared,
                      noResults: false
                  }
                : r
        );

        if (this._searchTimers[key]) {
            clearTimeout(this._searchTimers[key]);
        }
        if (isCleared) return;

        // Debounce the actual Apex call per row
        this._searchTimers[key] = setTimeout(() => {
            this.runSearch(key, term);
        }, SEARCH_DEBOUNCE_MS);
    }

    runSearch(key, term) {
        if (!this.selectedCategory) return;

        searchProducts({ category: this.selectedCategory, searchTerm: term })
            .then(results => {
                const selectedIds = new Set(
                    this.items
                        .filter(r => r.key !== key && r.productId)
                        .map(r => r.productId)
                );
                const filtered = (results || []).filter(p => !selectedIds.has(p.Id));
                this.items = this.items.map(r =>
                    r.key === key
                        ? {
                              ...r,
                              results: filtered,
                              searching: false,
                              noResults: filtered.length === 0,
                              showResults: true
                          }
                        : r
                );
            })
            .catch(error => {
                this.items = this.items.map(r =>
                    r.key === key
                        ? { ...r, results: [], searching: false, noResults: true }
                        : r
                );
                this.toast('Search failed', this.extractError(error), 'error');
            });
    }

    selectProduct(event) {
        // Prevent the input from blurring before the click commits
        if (event && event.preventDefault) event.preventDefault();

        // Walk up to the option element if a child span was clicked
        let el = event.currentTarget;
        if (!el || !el.dataset || !el.dataset.id) {
            el = event.target && event.target.closest ? event.target.closest('[data-id]') : null;
        }
        if (!el || !el.dataset || !el.dataset.id) return;

        const key = el.dataset.key;
        const id = el.dataset.id;
        const name = el.dataset.name;
        const code = el.dataset.code;

        // Prevent duplicate selection across rows
        const alreadyUsed = this.items.some(r => r.key !== key && r.productId === id);
        if (alreadyUsed) {
            this.toast('Duplicate', 'This product is already added to another row.', 'warning');
            return;
        }

        const display = code ? `${name} (${code})` : name;
        this.items = this.items.map(r =>
            r.key === key
                ? {
                      ...r,
                      productId: id,
                      searchTerm: display,
                      results: [],
                      showResults: false
                  }
                : r
        );
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
        // If hosted on an App Page, just reset
        this.resetForm();
    }

    handleSave() {
        if (!this.validate()) return;

        const payload = this.items.map(r => ({
            productId: r.productId,
            quantity: Number(r.quantity)
        }));

        this.isLoading = true;
        createStockRequestWithItems({
            category: this.selectedCategory,
            itemsJson: JSON.stringify(payload)
        })
            .then(stockRequestId => {
                this.toast('Success', 'Stock Request created successfully.', 'success');
                this.resetForm();
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: stockRequestId,
                        objectApiName: STOCK_REQUEST_OBJECT,
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.toast('Error', this.extractError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    validate() {
        if (!this.selectedCategory) {
            this.toast('Missing Category', 'Please select a Product Category.', 'warning');
            return false;
        }
        if (this.items.length === 0) {
            this.toast('No items', 'Add at least one product item.', 'warning');
            return false;
        }
        for (let i = 0; i < this.items.length; i++) {
            const r = this.items[i];
            if (!r.productId) {
                this.toast('Row ' + (i + 1), 'Select a product.', 'warning');
                return false;
            }
            if (r.quantity == null || Number(r.quantity) <= 0) {
                this.toast('Row ' + (i + 1), 'Quantity must be greater than 0.', 'warning');
                return false;
            }
        }
        return true;
    }

    resetForm() {
        this.selectedCategory = '';
        this.items = [];
        this._rowSeq = 0;
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
