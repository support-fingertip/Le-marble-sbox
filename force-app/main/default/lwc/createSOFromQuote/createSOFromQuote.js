import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPaymentTypeOptions from '@salesforce/apex/CreateSOFromQuoteController.getPaymentTypeOptions';
import getItemInventoryByWarehouse from '@salesforce/apex/SAPMasterDataService.getItemInventoryByWarehouse';
import getQuoteInfo from '@salesforce/apex/CreateSOFromQuoteController.getQuoteInfo';
import getQuoteLineItems from '@salesforce/apex/CreateSOFromQuoteController.getQuoteLineItems';
import createOrderFromQuote from '@salesforce/apex/CreateSOFromQuoteController.createOrderFromQuote';
import { NavigationMixin } from 'lightning/navigation';
import getActiveWarehouses from '@salesforce/apex/CreateSOFromQuoteController.getActiveWarehouses';
import getBatchStock from '@salesforce/apex/CreateSOFromQuoteController.getBatchStock';



const ALLOWED_WAREHOUSE_CODES = [
    'AMP0004', 'BDBS0022', 'IMAM0019', 'MLPB0001',
    'NSD0007', 'IMP0015', 'VNGS0003', 'VNGW0002'
];

export default class CreateSOFromQuote extends NavigationMixin(LightningElement) {
    showCreateSOButton = false;


    @track isQuoteItemsLoaded = false;
    @track selectedWarehouse;
    @track warehouseOptions = [];
    @track deliveryCommittedDate;
    @track remarks = '';
    @track credit = false;
    @track isAccountBlocked = false;
@track isFactoryWarehouse = false;

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
    
    isBatchModalOpen = false;
    batchList = [];
    batchQtyMap = {};
    selectedOrderItemId;

    get hasQuoteItems() {
    return this.isQuoteItemsLoaded &&
           this.quoteLineItems &&
           this.quoteLineItems.length > 0;
}
    get isConfirmDisabled() {
    return (
        this.isLoading ||
        !this.selectedWarehouse ||
        !this.deliveryCommittedDate ||
        !this.quoteLineItems.some(item => item.isSelected)
    );
}

    get hasCartItems() {
        return this.cartLineItems && this.cartLineItems.length > 0;
    }
    handleCreditToggle(event) {
        this.credit = event.target.checked;
        console.log('Credit Toggle Value:', this.credit);
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
            this.isAccountBlocked=quote.Account.Blocked_Account__c;

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
        this.remarks = '';
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
            const taxamt = item.Product2.Tax__c || 0;

            return {
                ...item,
                isSelected: true,  
                totalPrice : (quantity * unitPrice).toFixed(2),
             //   totalPrice: quantity * unitPrice, 
               // tax: (quantity * unitPrice) * 0.18, 
               tax: (quantity * unitPrice) *(taxamt/100),
                BlockQty:0,
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
                    value: w.Id,
                    type: w.Type__c 
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


    get isBatchEditable() {
        const quoteItem = this.quoteLineItems.find(
            i => i.Id === this.selectedOrderItemId
        );

        if (!quoteItem) return false;

        return quoteItem.category === 'ADHESIVE' || 
                quoteItem.category === 'TILE';
    }

    handleWarehouseSelect(event) {
    const warehouseCode = event.currentTarget.dataset.warehouse;

        this.quoteLineItems = this.quoteLineItems.map(item => {
            if (item.Id === this.selectedOrderItemId) {
                return {
                    ...item,
                    selectedWarehouseCode: warehouseCode,
                    batches: []  
                };
            }
            return item;
        });

        this.showToast(
            'Success',
            `Warehouse ${warehouseCode} selected`,
            'success'
        );

        this.closeBatchModal();
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

    handleRemarksChange(event) {
    this.remarks = event.target.value;
}



    handleWarehouseChange(event) {
    this.selectedWarehouse = event.detail.value;
     const selected = this.warehouseOptions.find(
        w => w.value === this.selectedWarehouse
    );

    this.isFactoryWarehouse = selected?.type === 'Factory';

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

    /*async handleItemWarehouseChange(event) {
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
    }*/

  /*  handlePaymentTypeChange(event) {
        this.selectedPaymentType = event.detail.value;
        // Clear credit amount and due date when payment type changes
        if (this.selectedPaymentType !== 'Credit') {
            this.creditAmount = '';
            this.creditDueDate = '';
        }
    }*/

    handleCreditAmountChange(event) {
        this.creditAmount = event.detail.value;
    }

    handleCreditDueDateChange(event) {
        this.creditDueDate = event.detail.value;
    }


    handleDeliveryDateChange(event) {
    this.deliveryCommittedDate = event.detail.value;
}
    handleBlockQtyChange(event) {
        const recordId = event.target.dataset.id;
        const value = event.target.value;

        this.quoteLineItems = this.quoteLineItems.map(item => {
            if (item.Id === recordId) {
                return {
                    ...item,
                    BlockQty: value ? Number(value) : 0
                };
            }
            return item;
        });
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

         if (!this.deliveryCommittedDate) {
            this.showToast(
                'Error',
                'Delivery Committed Date is required',
                'error'
            );
            this.isLoading = false;
            return;
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);

       // const selectedDate = new Date(this.deliveryCommittedDate);
    const selectedDate = new Date(this.deliveryCommittedDate + 'T00:00:00');
        if (selectedDate < today) {
            this.showToast(
                'Error',
                'Delivery Committed Date cannot be in the past',
                'error'
            );
            this.isLoading = false;
            return;
        }

                console.log('433>>');
        const batchPayload = [];
        selectedItems.forEach(item => {
            if (item.batches) {
                item.batches.forEach(b => {
                    batchPayload.push({
                        quoteLineItemId: item.Id,
                        Eid: b.Eid,
                        Batch: b.Batch,
                        warehouseCode: b.warehouseCode,
                        quantity: b.quantity
                    });
                });
            }
            });
  console.log('batchPayload>>'+batchPayload);
        const blockQtyMap = {};
        const warehouseCodeMap = {};
            selectedItems.forEach(item => {
            blockQtyMap[item.Id] = item.BlockQty || 0;
            if (item.selectedWarehouseCode) {
                warehouseCodeMap[item.Id] = item.selectedWarehouseCode;
            }
        });


    const orderId = await createOrderFromQuote({
    quoteId: this.recordId,
    warehouseId: this.selectedWarehouse,
    selectedQuoteLineItemIds: selectedItems.map(i => i.Id),
    blockQtyMap: blockQtyMap,
    warehouseCodeMap: warehouseCodeMap,
    deliveryCommittedDate: this.deliveryCommittedDate,
    remarks: this.remarks,
    credit : this.credit,
    batchJson: JSON.stringify(batchPayload)
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



handleViewBatch(event) {
        if (!this.selectedWarehouse) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Warehouse Not Selected',
                message: 'Please select the warehouse before viewing batch details.',
                variant: 'error'
            })
        );
        return; // ⛔ stop execution
    }

    // existing logic
    const qliId = event.currentTarget.dataset.id;

    this.selectedQuoteLineItemId = qliId;
    this.isBatchModalOpen = true;


    this.selectedOrderItemId = event.target.dataset.id;

   getBatchStock({
    orderItemId: this.selectedOrderItemId,
    warehouse: this.selectedWarehouse
})
.then(result => {
    const quoteItem = this.quoteLineItems.find(
        i => i.Id === this.selectedOrderItemId
    );

    const savedBatches = quoteItem?.batches || [];

    // merge saved quantities
    this.batchList = result.map(b => {
        const saved = savedBatches.find(sb => sb.Eid === b.Eid);
        return {
            ...b,
            quantity: saved ? saved.quantity : null
        };
    });
console.log('Batch List:', JSON.stringify(this.batchList));
    // ALSO rebuild batchQtyMap from saved data
    this.batchQtyMap = {};
    savedBatches.forEach(b => {
        this.batchQtyMap[b.Eid] = { ...b };
    });

    this.isBatchModalOpen = true;
})
.catch(error => {
    console.error(error);
});
}

handleBatchQtyChange(event) {
    const qty = Number(event.target.value);
    const eid = event.target.dataset.eid;

    if (!eid) return;
    // find the row from batchList
    const row = this.batchList.find(b => b.Eid === eid);
    if (!row) return;

     const quoteItem = this.quoteLineItems.find(
        i => i.Id === this.selectedOrderItemId
    );

    if (!quoteItem) return;

    // remove entry if qty is 0 or empty
    if (!qty || qty <= 0) {
        delete this.batchQtyMap[eid];
          this.batchList = this.batchList.map(b =>
            b.Eid === eid ? { ...b, quantity: null } : b
        );
        return;
    }
  let totalBatchQty = 0;
   Object.values(this.batchQtyMap).forEach(b => {
        if (b.Eid !== eid) {
            totalBatchQty += b.quantity || 0;
        }
    });

    totalBatchQty += qty;

    //  VALIDATION: batch qty > item qty
    if (totalBatchQty > quoteItem.Quantity) {
        this.showToast(
            'Error',
            `Total batch quantity (${totalBatchQty}) cannot exceed item quantity (${quoteItem.Quantity}).`,
            'error'
        );

        // reset input field
        event.target.value = null;
        return;
    }

    //Validation: cannot exceed available
        if (qty > row.inStock) {
        this.showToast(
            'Error',
            `Quantity cannot exceed available stock (${row.inStock})`,
            'error'
        );
        event.target.value = null;
        return;
        }

    // store complete row data
    this.batchQtyMap[eid] = {
        Eid: row.Eid,
        Batch: row.Batch,
        warehouseCode: row.warehouseCode,
        quantity: qty,
        inStock: row.inStock,
        reserved: row.reserved,
        billable: row.billable
    };
     this.batchList = this.batchList.map(b =>
        b.Eid === eid
            ? { ...b, quantity: qty }
            : b
    );

    console.log('Batch Qty Map:', JSON.stringify(this.batchQtyMap));
}
handleEditBatch(event) {
    this.selectedOrderItemId = event.currentTarget.dataset.qli;
    this.isBatchModalOpen = true;

    const quoteItem = this.quoteLineItems.find(
        i => i.Id === this.selectedOrderItemId
    );

    if (!quoteItem || !quoteItem.batches) return;

    // rebuild batchList from saved batches
    this.batchList = quoteItem.batches.map(b => ({
        ...b
    }));

    // rebuild batchQtyMap
    this.batchQtyMap = {};
    quoteItem.batches.forEach(b => {
        this.batchQtyMap[b.Eid] = { ...b };
    });
}

handleDeleteBatch(event) {


    const qliId = event.currentTarget.dataset.qli;
    const eid = event.currentTarget.dataset.eid;

    this.quoteLineItems = this.quoteLineItems.map(item => {
        if (item.Id === qliId && item.batches) {

            // remove the selected batch
            const updatedBatches = item.batches.filter(b => b.Eid !== eid);

            // recalculate Block Qty
            const updatedBlockQty = updatedBatches.reduce(
                (sum, b) => sum + (b.quantity || 0),
                0
            );

            return {
                ...item,
                batches: updatedBatches,
                BlockQty: updatedBlockQty
            };
        }
        return item;
    });

    // Optional: clean from batchQtyMap if exists
    if (this.batchQtyMap[eid]) {
        delete this.batchQtyMap[eid];
    }

    this.showToast('Success', 'Batch removed successfully', 'success');
}


closeBatchModal(){
    this.isBatchModalOpen = false;
  //  this.batchQtyMap = {};
}

saveBatchItems() {
    const batchList = Object.values(this.batchQtyMap);

    const totalBatchQty = batchList.reduce(
        (sum, b) => sum + (b.quantity || 0),
        0
    );

    // attach batches to correct quote item
    this.quoteLineItems = this.quoteLineItems.map(item => {
        if (item.Id === this.selectedOrderItemId) {
            return {
                ...item,
                batches: batchList,   //  store only in JS
                BlockQty: totalBatchQty
            };
        }
        return item;
    });

    this.closeBatchModal();
}


get backgroundClass() {
    return this.isBatchModalOpen
        ? 'blur-background'
        : '';
}

    /*getProductInStock(item) {
        return item && item.Product__r && item.Product__r.In_Stock__c ? item.Product__r.In_Stock__c : 'N/A';
    }*/
}