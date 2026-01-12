import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCartLineItemsByDeal from '@salesforce/apex/SalesConfirmationController.getCartLineItemsByDeal';
import createSalesConfirmation from '@salesforce/apex/SalesConfirmationController.createSalesConfirmation';
import getPaymentTypeOptions from '@salesforce/apex/SalesConfirmationController.getPaymentTypeOptions';
import getDealInfo from '@salesforce/apex/SalesConfirmationController.getDealInfo';
import getActiveBusinessPlaces from '@salesforce/apex/SAPMasterDataService.getActiveBusinessPlaces';
import getWarehousesByBPL from '@salesforce/apex/SAPMasterDataService.getWarehousesByBPL';
import getItemInventoryByWarehouse from '@salesforce/apex/SAPMasterDataService.getItemInventoryByWarehouse';

const ALLOWED_WAREHOUSE_CODES = [
    'AMP0004', 'BDBS0022', 'IMAM0019', 'MLPB0001',
    'NSD0007', 'IMP0015', 'VNGS0003', 'VNGW0002'
];

export default class SalesConfirmationButton extends LightningElement {
    @api recordId; // Deal Id
    @track isModalOpen = false;
    @track cartLineItems = [];
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

    @wire(getDealInfo, { dealId: '$recordId' })
    wiredDealInfo({ error, data }) {
        if (data) {
            const addressParts = [];
            if (data.Address__Street__s) addressParts.push(data.Address__Street__s);
            let cityState = '';
            if (data.Address__City__s) cityState += data.Address__City__s;
            if (data.Address__StateCode__s) {
                if (cityState) cityState += ', ';
                cityState += data.Address__StateCode__s;
            }
            if (cityState) addressParts.push(cityState);
            if (data.Address__PostalCode__s) addressParts.push(data.Address__PostalCode__s);
            if (data.Address__CountryCode__s) addressParts.push(data.Address__CountryCode__s);
            const formattedAddress = addressParts.filter(part => part && part.trim() !== '').join(', ');
            const name = data.Customer__r ? data.Customer__r.Name : data.Name;
            const email = data.Customer__r && data.Customer__r.Email__c ? data.Customer__r.Email__c : data.Email__c;
            const phone = data.Customer__r && data.Customer__r.Phone__c ? data.Customer__r.Phone__c : data.Phone__c;
            const company = data.Customer__r && data.Customer__r.Company__c ? data.Customer__r.Company__c : data.Company__c;
            const executive = data.Owner && data.Owner.Name ? data.Owner.Name : 'N/A';
            this.customerInfo = {
                name: name || 'N/A',
                email: email || 'N/A',
                phone: phone || 'N/A',
                company: company || 'N/A',
                address: formattedAddress || 'N/A',
                executive: executive
            };
        } else if (error) {
            this.showToast('Error', 'Failed to fetch deal information', 'error');
        }
    }

    @wire(getCartLineItemsByDeal, { dealId: '$recordId' })
    wiredCartLineItems({ error, data }) {
        if (data) {
            // Filter items with Status__c equal to 'Approved'
            const approvedItems = data.filter(item => item.Cart__r.Status__c === 'Approved');
            this.cartLineItems = approvedItems.map(item => ({
                ...item,
                isSelected: false,
                isDisabled: true,
                selectedWarehouse: '',
                warehouseOptions: [],
                productName: item && item.Product__r && item.Product__r.Name ? item.Product__r.Name : 'N/A',
                productInStock: item && item.Product__r && item.Product__r.In_Stock__c ? item.Product__r.In_Stock__c : 'N/A'
            }));
            this.groupCartItems();
        } else if (error) {
            this.showToast('Error', error.body?.message || 'Failed to fetch cart items', 'error');
            this.cartLineItems = [];
            this.groupCartItems();
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
            const cartId = item.Cart__c;
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
            console.log('Fetching warehouses for item:', item.Product__r.Product_Code__c);
            const inventoryList = await getItemInventoryByWarehouse({
                warehouseCode: null,
                itemCodes: [item.Product__r.Product_Code__c]
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
                this.showToast('Info', `No warehouses found for ${item.Product__r.Name}`, 'info');
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
        if (!this.validateForm()) return;
        this.isLoading = true;
        try {
            const selectedLineItems = this.cartLineItems
                .filter(item => item.isSelected)
                .map(item => ({
                    Id: item.Id,
                    Warehouse__c: item.selectedWarehouse,
                    WarehouseName: item.selectedWarehouseName,
                    Location: item.selectedLocation
                }));

            // Get BPL from first selected item's warehouse
            const firstItem = this.cartLineItems.find(item => item.isSelected);
            const firstWarehouseOption = firstItem.warehouseOptions.find(w => w.value === firstItem.selectedWarehouse);
            const bplId = firstWarehouseOption ? firstWarehouseOption.bplId : null;

            await createSalesConfirmation({
                dealId: this.recordId,
                selectedLineItems: selectedLineItems,
                paymentType: this.selectedPaymentType,
                creditAmount: this.creditAmount,
                creditDueDate: this.creditDueDate,
                BPL_IDAssignedToInvoice: bplId,
                Warehouse_IDAssignedToInvoice: selectedLineItems[0]?.Warehouse__c
            });
            this.showToast('Success', 'Sales confirmation created successfully', 'success');
            this.handleCloseModal();
        } catch (error) {
            console.error('Error creating sales confirmation:', error);
            this.showToast('Error', error.body?.message || 'Failed to create sales confirmation', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    validateForm() {
        const selectedItems = this.cartLineItems.filter(item => item.isSelected);
        if (selectedItems.length === 0) {
            this.showToast('Error', 'Please select at least one item', 'error');
            return false;
        }
        const itemsWithoutWarehouse = selectedItems.filter(item => !item.selectedWarehouse);
        if (itemsWithoutWarehouse.length > 0) {
            this.showToast('Error', 'Please select a warehouse for all selected items', 'error');
            return false;
        }
        if (!this.selectedPaymentType) {
            this.showToast('Error', 'Please select a payment type', 'error');
            return false;
        }
        if (this.selectedPaymentType === 'Credit') {
            if (!this.creditAmount || parseFloat(this.creditAmount) <= 0) {
                this.showToast('Error', 'Please enter a valid credit amount', 'error');
                return false;
            }
            if (!this.creditDueDate) {
                this.showToast('Error', 'Please select a credit due date', 'error');
                return false;
            }
        }
        return true;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
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
        return item && item.Product__r && item.Product__r.Name ? item.Product__r.Name : 'N/A';
    }
    getProductInStock(item) {
        return item && item.Product__r && item.Product__r.In_Stock__c ? item.Product__r.In_Stock__c : 'N/A';
    }
}