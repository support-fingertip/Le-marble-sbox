import { LightningElement, wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchSalesConfirmations from '@salesforce/apex/NewDeliveryPlanController.searchSalesOrders';
import getAvailableProducts from '@salesforce/apex/NewDeliveryPlanController.getAvailableProducts';
import createDeliveryGroup from '@salesforce/apex/NewDeliveryPlanController.createDeliveryGroup';
import getVehicleTypeOptions from '@salesforce/apex/NewDeliveryPlanController.getVehicleTypeOptions';
import getDriverPicklistOptions from '@salesforce/apex/NewDeliveryPlanController.getDriverPicklistOptions';
import getVehicleNumberOptions from '@salesforce/apex/NewDeliveryPlanController.getVehicleNumberOptions';

export default class NewDeliveryPlan extends LightningElement {
    @track searchTerm = '';
    @track salesConfirmations = [];
    @track selectedSalesConfirmationId;
    @track selectedQuoteId;
    @track availableProducts = [];
    @track deliveryDate;
    @track selectedDriver = '';
    @track selectedVehicle = '';
    @track selectedWarehouse;
    @track remarks;
    @track driverOptions = [];
    @track warehouseOptions = [];
    @track isCreateButtonDisabled = true;
    @track selectedSalesConfirmation;
    @track activeTab = 'available';
    @track vehicleOptions = [];
    @track freightAmount;
    @track deliveryTime;
    @track vehicleNumber;
    @track vehicleNumberOptions = [];
    @api recordId;

    vehicleTypeToNumbers = {
        BOLERO: [
            'KL 11 AV 5223', 'KL 11 AQ 805', 'KL 11 AM 949'
        ],
        DHOSTH: [
            'KL 11 AS 7257', 'KL 11 BD 3166', 'KL 11 BD 3866'
        ],
        NISSAN: [
            'KL 11 AC 7775', 'KL 11 Y 714', 'KL 11Z 9884', 'KL 11 AA 2757', 'KL 11 AA 5504', 'KL 11 AH 5550', 'KL 11 AH 5563', 'KL 11 AY 7607', 'KL 11 AY 7709', 'KL11CB2632', 'KL11CB2634'
        ],
        BENZ: [
            'KL11 BL 5396', 'KL11 BT 6859'
        ]
    };

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        window.clearTimeout(this.searchTimeout);
        this.searchTimeout = window.setTimeout(() => {
            if (this.searchTerm.length >= 2) {
                this.searchSalesConfirmations();
            } else {
                this.salesConfirmations = [];
            }
        }, 300);
    }

    handleTabClick(event) {
        // Only one tab now, so no-op or can be removed
    }

    get isAvailableTabActive() {
        return true;
    }

    get availableTabClass() {
        return 'tab active';
    }

    async searchSalesConfirmations() {
        try {
            const results = await searchSalesConfirmations({ searchTerm: this.searchTerm });
            this.salesConfirmations = results.map(sc => ({
                label: sc.OrderNumber + (sc.Product_Category__c ? ` (${sc.Product_Category__c})` : ''),
                value: sc.Id,
                details: {
                    name: sc.OrderNumber,
                    quoteName: sc.Quote_Name__c,
                    company: sc.Account.Name,
                    orderOwner:sc.Order_Owner__c,
                  //  customerName: sc.Opportunity__r.Customer__r.Name,
                    phone: sc.Phone__c,
                    address: {
                        street: sc.BillingStreet,
                        city: sc.BillingCity,
                        state: sc.BillingState,
                        postalCode: sc.BillingPostalCode,
                        country: sc.BillingCountry
                    },
               //     stage: sc.Opportunity__r.Stage__c,
               //     type: sc.Opportunity__r.Type__c,
               //      oppOwner: sc.Opportunity__r.Owner?.Order_Owner__c,
                    totalAmount: sc.TotalAmount,
               //     paymentType: sc.Payment_Type__c,
                    warehouse: sc.Warehouse__c,
                //    approvalStatus: sc.Approval_Status__c,
                    productCategory: sc.Product_Category__c,
                    QuoteId: sc.QuoteId,
                    cartLineItems: sc.OrderItems || [],
                //    preferredDeliveryDate: sc.Preferred_Delivery_Date__c
                }
            }));
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error searching sales Order', 'error');
        }
    }

    handleSalesConfirmationSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selectedSC = this.salesConfirmations.find(sc => sc.value === selectedId);
        if (selectedSC) {
            this.selectedSalesConfirmationId = selectedSC.value;
            this.selectedSalesConfirmation = selectedSC.details;
            this.selectedQuoteId = selectedSC.details.QuoteId;
            this.searchTerm = selectedSC.label;
            this.salesConfirmations = [];
            this.loadInitialData();
        }
    }

    async loadInitialData() {
        if (!this.selectedSalesConfirmationId) return;
        try {
            // Load available products
            const availableProductsResult = await getAvailableProducts({ 
                salesConfirmationId: this.selectedSalesConfirmationId 
            });
            this.availableProducts = availableProductsResult.map(product => ({
                ...product,
                selected: false,
                deliveryQuantity: product.Quantity,
                displayName: `${product.Product2.Name} - Available: ${product.Quantity}`
            }));
            // Load driver picklist
            const driverPicklist = await getDriverPicklistOptions();
            this.driverOptions = driverPicklist.map(option => ({ label: option, value: option }));
            // Load vehicle picklist
            const vehiclePicklist = await getVehicleTypeOptions();
            this.vehicleOptions = vehiclePicklist.map(option => ({ label: option, value: option }));
            this.validateForm();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading data', 'error');
        }
    }

    handleProductSelection(event) {
        const productId = event.target.dataset.id;
        const product = this.availableProducts.find(p => p.Id === productId);
        if (product) {
            product.selected = event.target.checked;
            if (product.selected) {
                product.deliveryQuantity = product.Quantity;
            }
            this.validateForm();
        }
    }

    handleDeliveryQuantityChange(event) {
        const productId = event.target.dataset.id;
        const product = this.availableProducts.find(p => p.Id === productId);
        if (product) {
            // Allow any value while typing
            product.deliveryQuantity = event.target.value;
        }
    }

    handleDeliveryQuantityBlur(event) {
        const productId = event.target.dataset.id;
        const product = this.availableProducts.find(p => p.Id === productId);
        if (product) {
            const newQuantity = parseFloat(product.deliveryQuantity);
            if (!newQuantity || newQuantity < 1) {
                product.deliveryQuantity = 1;
            } else if (newQuantity > product.Quantity) {
                product.deliveryQuantity = product.Quantity;
                this.showToast('Warning', 'Quantity cannot exceed available amount', 'warning');
            } else {
                product.deliveryQuantity = newQuantity;
            }
            // Force re-render if needed
            this.availableProducts = [...this.availableProducts];
        }
    }

    handleDateChange(event) {
        this.deliveryDate = event.target.value;
        this.validateForm();
    }

    handleDriverChange(event) {
        this.selectedDriver = event.target.value;
        this.validateForm();
    }

    handleVehicleChange(event) {
        this.selectedVehicle = event.target.value;
        // Update vehicle number options based on selected vehicle type
        this.vehicleNumberOptions = (this.vehicleTypeToNumbers[this.selectedVehicle] || []).map(num => ({ label: num, value: num }));
        this.vehicleNumber = ''; // Reset vehicle number selection
        this.validateForm();
    }

    handleWarehouseChange(event) {
        this.selectedWarehouse = event.target.value;
        this.validateForm();
    }

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    handleFreightAmountChange(event) {
        this.freightAmount = event.target.value;
    }

    handleDeliveryTimeChange(event) {
        this.deliveryTime = event.target.value;
    }

    handleVehicleNumberChange(event) {
        this.vehicleNumber = event.target.value;
    }

    validateForm() {
        const hasSelectedProducts = this.availableProducts.some(product => product.selected);
        const hasValidQuantities = this.availableProducts.every(product => 
            !product.selected || (product.deliveryQuantity > 0 && product.deliveryQuantity <= product.Quantity)
        );
        const hasRequiredFields = this.deliveryDate && this.selectedDriver && this.selectedVehicle;
        
        this.isCreateButtonDisabled = !(hasSelectedProducts && hasValidQuantities && hasRequiredFields);
    }

    async handleCreateDeliveryGroup() {
        try {
            const selectedProducts = this.availableProducts
                .filter(product => product.selected)
                .map(product => ({
                    id: product.Id,
                    deliveryQuantity: product.deliveryQuantity
                }));

            const deliveryGroupData = {
                salesConfirmationId: this.selectedSalesConfirmationId,
                deliveryDate: this.deliveryDate,
                driverId: this.selectedDriver,
                vehicleId: this.selectedVehicle,
                vehicleNumber: this.vehicleNumber,
                freightAmount: this.freightAmount !== undefined && this.freightAmount !== null && this.freightAmount !== '' ? Number(this.freightAmount) : null,
                deliveryTime: this.deliveryTime,
                warehouseId: this.selectedWarehouse,
                remarks: this.remarks,
                productData: selectedProducts
            };

            await createDeliveryGroup({ deliveryGroupData: JSON.stringify(deliveryGroupData) });
            this.showToast('Success', 'Delivery Plan created successfully', 'success');
            
            // Reset form
            this.deliveryDate = null;
            this.selectedDriver = '';
            this.selectedVehicle = '';
            this.vehicleNumber = '';
            this.selectedWarehouse = '';
            this.remarks = '';
            this.freightAmount = null;
            this.deliveryTime = null;
            
            // Refresh data
            await this.loadInitialData();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to create Delivery Plan', 'error');
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get selectedSalesConfirmationInfo() {
        if (!this.selectedSalesConfirmation) return null;
        const addr = this.selectedSalesConfirmation.address || {};
        const formattedAddress = [addr.street, addr.city, addr.state, addr.postalCode, addr.country]
            .filter(Boolean)
            .join(', ');
        return {
            name: this.selectedSalesConfirmation.name,
            quoteName: this.selectedSalesConfirmation.quoteName,
            oppOwner: this.selectedSalesConfirmation.oppOwner || 'N/A',
            company: this.selectedSalesConfirmation.company || 'N/A',
            customerName: this.selectedSalesConfirmation.customerName || 'N/A',
            phone: this.selectedSalesConfirmation.phone || 'N/A',
            address: formattedAddress || 'N/A',
            stage: this.selectedSalesConfirmation.stage || 'N/A',
            type: this.selectedSalesConfirmation.type || 'N/A',
            totalAmount: this.selectedSalesConfirmation.totalAmount || 'N/A',
            paymentType: this.selectedSalesConfirmation.paymentType || 'N/A',
            warehouse: this.selectedSalesConfirmation.warehouse || 'N/A',
            approvalStatus: this.selectedSalesConfirmation.approvalStatus || 'N/A',
            productCategory: this.selectedSalesConfirmation.productCategory || 'N/A',
            preferredDeliveryDate: this.selectedSalesConfirmation.preferredDeliveryDate || null
        };
    }
}