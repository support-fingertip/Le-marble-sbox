import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//import getCartLineItemsByDeal from '@salesforce/apex/CreateSOFromQuoteController.getCartLineItemsByDeal';
//import createSalesConfirmation from '@salesforce/apex/CreateSOFromQuoteController.createSalesConfirmation';
import getPaymentTypeOptions from '@salesforce/apex/CreateSOFromQuoteController.getPaymentTypeOptions';
//import getDealInfo from '@salesforce/apex/CreateSOFromQuoteController.getDealInfo';
//import getActiveBusinessPlaces from '@salesforce/apex/SAPMasterDataService.getActiveBusinessPlaces';
//import getWarehousesByBPL from '@salesforce/apex/SAPMasterDataService.getWarehousesByBPL';
import getItemInventoryByWarehouse from '@salesforce/apex/SAPMasterDataService.getItemInventoryByWarehouse';
import getQuoteInfo from '@salesforce/apex/CreateSOFromQuoteController.getQuoteInfo';
import getQuoteLineItems from '@salesforce/apex/CreateSOFromQuoteController.getQuoteLineItems';
import createOrderFromQuote from '@salesforce/apex/CreateSOFromQuoteController.createOrderFromQuote';
import { NavigationMixin } from 'lightning/navigation';
import getActiveWarehouses from '@salesforce/apex/CreateSOFromQuoteController.getActiveWarehouses';



const ALLOWED_WAREHOUSE_CODES = [
    'AMP0004', 'BDBS0022', 'IMAM0019', 'MLPB0001',
    'NSD0007', 'IMP0015', 'VNGS0003', 'VNGW0002'
];

export default class CreateSOFromQuote extends NavigationMixin(LightningElement) {
    showCreateSOButton = false;


    @track isQuoteItemsLoaded = false;
    @track selectedWarehouse;
    @track warehouseOptions = [];

    @api recordId; 
    @track isModalOpen = false;
    @track cartLineItems = [];
    @track quoteLineItems = [];
    @track paymentTypeOptions = [];
    @track selectedPaymentType = '';
    @track creditAmount = '';
    @track creditDueDate = '';
    @track isLoading = false;
    @track cartGroups = [];
    @track expandedCartIds = new Set();
    @track customerInfo = {
        name: '',
        email: '',
        phone: '',
        company: '',
        address: '',
        executive: ''
    };
    
    get hasQuoteItems() {
    return this.isQuoteItemsLoaded &&
           this.quoteLineItems &&
           this.quoteLineItems.length > 0;
}
    get isConfirmDisabled() {
    return (
        this.isLoading ||
        !this.selectedWarehouse ||
        !this.quoteLineItems.some(item => item.isSelected)
    );
}

    get hasCartItems() {
        return this.cartLineItems && this.cartLineItems.length > 0;
    }

    get showCreditAmount() {
        return this.selectedPaymentType === 'Credit';
    }

    get showCreditDueDate() {
        return this.selectedPaymentType === 'Credit';
    }

    get groupedCartItems() {
        return this.hasCartItems;
    }

   @wire(getQuoteInfo, { quoteId: '$recordId' })
wiredQuoteInfo({ error, data }) {
    if (data) {
        const quote = data.quote; 


        this.showCreateSOButton = !quote.Sales_Order_Created__c;

        this.customerInfo = {
            name: quote.Name || 'N/A',
            email: data.email || 'N/A',   
            phone: quote.Account?.Phone || 'N/A',
            company: quote.Account?.Name || 'N/A',
            address: quote.Account
                ? [
                    quote.Account.BillingStreet,
                    quote.Account.BillingCity,
                    quote.Account.BillingState,
                    quote.Account.BillingPostalCode,
                    quote.Account.BillingCountry
                  ].filter(Boolean).join(', ')
                : 'N/A',
            executive: quote.Owner?.Name || 'N/A'
        };
    } else if (error) {
        console.error(error);
        this.showToast('Error', 'Failed to fetch quote information', 'error');
    }
}

    @wire(getQuoteLineItems, { quoteId: '$recordId' })
    wiredQuoteLineItems({ error, data }) {
    this.isQuoteItemsLoaded = true;

    if (data) {
        this.quoteLineItems = data.map(item => {
            const quantity = item.Quantity || 0;
            const unitPrice = item.UnitPrice || 0;

            return {
                ...item,
                isSelected: true,  
                totalPrice: quantity * unitPrice, 
                tax: (quantity * unitPrice) * 0.18, 
                category: item.PricebookEntry?.Product2?.Product_Category__c || 'N/A'
            };
        });
    } else if (error) {
        this.quoteLineItems = [];
        this.showToast(
            'Error',
            error.body?.message || 'Failed to fetch quote line items',
            'error'
        );
    }
}

        @wire(getActiveWarehouses)
        wiredWarehouses({ data, error }) {
            if (data) {
                this.warehouseOptions = data.map(w => ({
                    label: w.Name,
                    value: w.Id
                }));
            } else if (error) {
                this.showToast('Error', 'Failed to load warehouses', 'error');
            }
        }

   
   @wire(getPaymentTypeOptions)
    wiredPaymentTypes({ error, data }) {
        if (data) {
            this.paymentTypeOptions = data;
        } else if (error) {
            this.showToast('Error', error.body?.message || 'Failed to fetch payment types', 'error');
        }
    }

    groupCartItems() {
        const groupedByCart = {};
        this.cartLineItems.forEach(item => {
            const cartId = item.QuoteId;
            if (!groupedByCart[cartId]) {
                groupedByCart[cartId] = [];
            }
            groupedByCart[cartId].push(item);
        });
        const cartIds = Object.keys(groupedByCart);
        if (this.expandedCartIds.size === 0 && cartIds.length > 0) {
            this.expandedCartIds.add(cartIds[0]);
        }
        this.cartGroups = cartIds.map(cartId => {
            const isExpanded = this.expandedCartIds.has(cartId);
            return {
                cartId: cartId,
                label: `Cart (${groupedByCart[cartId].length} items)` ,
                items: groupedByCart[cartId],
                iconName: 'utility:cart',
                expandIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                contentClass: isExpanded ? 'slds-show' : 'slds-hide'
            };
        });
    }

    handleCloseModal() {
        this.isModalOpen = false;
        this.selectedPaymentType = '';
        this.creditAmount = '';
        this.creditDueDate = '';
        this.cartLineItems = this.cartLineItems.map(item => ({
            ...item,
            isSelected: false,
            isDisabled: true,
            selectedWarehouse: '',
            warehouseOptions: []
        }));
        this.groupCartItems();
    }


    handleWarehouseChange(event) {
    this.selectedWarehouse = event.detail.value;
}

    handleProductSelection(event) {
    const itemId = event.target.dataset.id;
    const checked = event.target.checked;

    this.quoteLineItems = this.quoteLineItems.map(item => {
        if (item.Id === itemId) {
            return { ...item, isSelected: checked };
        }
        return item;
    });
}

    handleItemSelection(event) {
        const itemId = event.target.dataset.id;
        const isSelected = event.target.checked;
        this.cartLineItems = this.cartLineItems.map(item => {
            if (item.Id === itemId) {
                return {
                    ...item,
                    isSelected,
                    isDisabled: !isSelected,
                    selectedWarehouse: '',
                    warehouseOptions: []
                };
            }
            return item;
        });
        if (isSelected) {
            const item = this.cartLineItems.find(i => i.Id === itemId);
            this.fetchWarehousesForItem(item);
        }
        this.groupCartItems();
    }

    async fetchWarehousesForItem(item) {
        if (!item) return;
        this.isLoading = true;
        try {
            console.log('Fetching warehouses for item:', item.Product2.ProductCode);
            const inventoryList = await getItemInventoryByWarehouse({
                warehouseCode: null,
                itemCodes: [item.Product2.ProductCode]
            });
            console.log('Inventory list received:', inventoryList);

            const filteredInventoryList = inventoryList.filter(w =>
                ALLOWED_WAREHOUSE_CODES.includes(w.WarehouseCode)
            );

            this.cartLineItems = this.cartLineItems.map(i => {
                if (i.Id === item.Id) {
                    const warehouseOptions = filteredInventoryList.map(w => ({
                        label: `${w.WarehouseName} (Stock: ${w.InStock}, Committed: ${w.Committed ?? 0})`,
                        value: w.WarehouseCode,
                        bplId: w.BusinessPlaceID,
                        inStock: w.InStock,
                        warehouseName: w.WarehouseName,
                        location: w.Location,
                        Committed: w.Committed ?? 0
                    }));
                    console.log('Warehouse options for item:', warehouseOptions);
                    return {
                        ...i,
                        warehouseOptions,
                        isDisabled: !i.isSelected
                    };
                }
                return i;
            });
            this.groupCartItems();
            
            if (inventoryList.length === 0) {
                this.showToast('Info', `No warehouses found for ${item.Product2.Name}`, 'info');
            }
        } catch (e) {
            console.error('Error fetching warehouses:', e);
            this.showToast('Error', 'Failed to load warehouses for selected product', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleItemWarehouseChange(event) {
        const itemId = event.target.dataset.id;
        const selectedWarehouse = event.detail.value;
        
        // Find the warehouse data to get BPL
        const item = this.cartLineItems.find(i => i.Id === itemId);
        const warehouseOption = item.warehouseOptions.find(w => w.value === selectedWarehouse);
        const bplId = warehouseOption ? warehouseOption.bplId : null;
        const inStock = warehouseOption ? warehouseOption.inStock : 0;
        const warehouseName = warehouseOption ? warehouseOption.warehouseName : '';
        const location = warehouseOption ? warehouseOption.location : '';
        
        // Validate stock level
        if (inStock <= 0) {
            this.showToast('Warning', 'Selected warehouse has no stock available', 'warning');
        }
        
        this.cartLineItems = this.cartLineItems.map(item => {
            if (item.Id === itemId) {
                return { 
                    ...item, 
                    selectedWarehouse,
                    selectedBPL: bplId,
                    selectedWarehouseName: warehouseName,
                    selectedLocation: location
                };
            }
            return item;
        });
        this.groupCartItems();
    }

    handlePaymentTypeChange(event) {
        this.selectedPaymentType = event.detail.value;
        // Clear credit amount and due date when payment type changes
        if (this.selectedPaymentType !== 'Credit') {
            this.creditAmount = '';
            this.creditDueDate = '';
        }
    }

    handleCreditAmountChange(event) {
        this.creditAmount = event.detail.value;
    }

    handleCreditDueDateChange(event) {
        this.creditDueDate = event.detail.value;
    }

    async handleOpenModal() {
        this.isLoading = true;
        this.isModalOpen = true;
        try {
            if (!this.paymentTypeOptions.length) {
                this.showToast('Warning', 'No Payment Types available', 'warning');
            }
        } catch (e) {
            this.showToast('Error', 'Failed to load dropdown data', 'error');
        } finally {
            this.isLoading = false;
        }
    }
       
    async handleConfirmSale() {
    this.isLoading = true;
    try {
        // 1️Warehouse
        if (!this.selectedWarehouse) {
    this.showToast('Error', 'Please select a Warehouse', 'error');
    this.isLoading = false;
    return;
}
     // 2. GET SELECTED PRODUCTS (THIS WAS MISSING)
        const selectedItems = this.quoteLineItems.filter(i => i.isSelected);

        // 3. Validate product selection
        if (selectedItems.length === 0) {
            this.showToast('Error', 'Please select at least one product', 'error');
            this.isLoading = false;
            return;
        }

    const orderId = await createOrderFromQuote({
    quoteId: this.recordId,
    warehouseId: this.selectedWarehouse,
    selectedQuoteLineItemIds: selectedItems.map(i => i.Id)
});
        this.showToast(
            'Success',
            'Sales Order created successfully',
            'success'
        );

        this.isModalOpen = false;


        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: orderId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });

    } catch (error) {
        this.showToast(
            'Error',
            error.body?.message || 'Failed to create Sales Order',
            'error'
        );
    } finally {
        this.isLoading = false;
    }
}


validateForm() {
   const selectedItems = this.quoteLineItems.filter(item => item.isSelected);
    if (selectedItems.length === 0) {
        this.showToast('Error', 'Please select at least one item', 'error');
        return false;
    }
    return true;
}

showToast(title, message, variant) {
    this.dispatchEvent(
        new ShowToastEvent({
            title,
            message,
            variant
        })
    );
}


    toggleCartSection(event) {
        const cartId = event.currentTarget.dataset.cartId;
        const isExpanded = this.expandedCartIds.has(cartId);

        if (isExpanded) {
            this.expandedCartIds.delete(cartId);
        } else {
            this.expandedCartIds.add(cartId);
        }

        this.cartGroups = this.cartGroups.map(group => {
            if (group.cartId === cartId) {
                return {
                    ...group,
                    expandIcon: this.expandedCartIds.has(cartId) ? 'utility:chevrondown' : 'utility:chevronright',
                    contentClass: this.expandedCartIds.has(cartId) ? 'slds-show' : 'slds-hide'
                };
            }
            return group;
        });
    }

    // Add safe accessors for product name and in stock
    getProductName(item) {
    return item?.Product2?.Name || 'N/A';
}

    /*getProductInStock(item) {
        return item && item.Product__r && item.Product__r.In_Stock__c ? item.Product__r.In_Stock__c : 'N/A';
    }*/
}