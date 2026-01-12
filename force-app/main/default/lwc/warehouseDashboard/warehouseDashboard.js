import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WarehouseDashboard extends LightningElement {
    @track isLoading = false;
    @track showStockModal = false;
    @track stockUpdateData = { productId: '', quantity: 0 };

    // Dummy data for the dashboard
    warehouseData = {
        name: 'Main Warehouse',
        location: '123 Marble Street, Warehouse District',
        manager: 'John Smith',
        capacity: 10000,
        currentStock: 7250,
        reservedStock: 2430,
        pendingOrders: 18
    };

    // Open stock update modal
    openStockUpdateModal(event) {
        const productId = event.currentTarget.dataset.productid || '';
        const productName = event.currentTarget.dataset.productname || '';
        
        this.stockUpdateData = { 
            productId: productId,
            productName: productName,
            quantity: 0
        };
        this.showStockModal = true;
    }

    // Close stock update modal
    closeStockModal() {
        this.showStockModal = false;
    }

    // Handle quantity change in stock update modal
    handleQuantityChange(event) {
        this.stockUpdateData.quantity = event.target.value;
    }

    // Update stock quantity
    updateStock() {
        this.isLoading = true;
        
        // Simulate API call
        setTimeout(() => {
            this.showToast('Success', 'Stock updated successfully', 'success');
            this.closeStockModal();
            this.isLoading = false;
        }, 1000);
    }

    // Block stock for a sales order
    blockStock(event) {
        const orderId = event.currentTarget.dataset.orderid || '';
        this.isLoading = true;
        
        // Simulate API call
        setTimeout(() => {
            this.showToast('Success', 'Stock blocked for order ' + orderId, 'success');
            this.isLoading = false;
        }, 1000);
    }

    // Create purchase order request
    createPurchaseOrder(event) {
        const orderId = event.currentTarget.dataset.orderid || '';
        this.isLoading = true;
        
        // Simulate API call
        setTimeout(() => {
            this.showToast('Success', 'Purchase order request created for order ' + orderId, 'success');
            this.isLoading = false;
        }, 1000);
    }

    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}