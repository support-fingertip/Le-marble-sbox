import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getDeliveryGroups from '@salesforce/apex/DeliverySchedulingController.getDeliveryGroups';
import markDeliveryAsCompleted from '@salesforce/apex/DeliverySchedulingController.markDeliveryAsCompleted';

export default class DeliveryScheduling extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track searchTerm = '';
    @track deliveryGroups = [];
    searchTimeout;

    // Stats getters
    get totalPendingDeliveries() {
        return this.deliveryGroups.filter(delivery => delivery.Status__c === 'Pending').length;
    }

    get totalInTransit() {
        return this.deliveryGroups.filter(delivery => delivery.Status__c === 'In Transit').length;
    }

    get totalDelivered() {
        return this.deliveryGroups.filter(delivery => delivery.Status__c === 'Delivered').length;
    }

    get totalAssignedVehicles() {
        return this.deliveryGroups.filter(delivery => 
            delivery.Vehicle_Assigned__c && delivery.Status__c === 'In Transit'
        ).length;
    }

    // Lifecycle hooks
    connectedCallback() {
        this.loadDeliveryGroups();
    }

    // Methods for status classes
    getStatusClass(status) {
        switch (status) {
            case 'Pending':
                return 'status-badge status-pending';
            case 'In Transit':
                return 'status-badge status-transit';
            case 'Delivered':
                return 'status-badge status-delivered';
            default:
                return '';
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        // Debounce the search to avoid too many server calls
        window.clearTimeout(this.searchTimeout);
        this.searchTimeout = window.setTimeout(() => {
            this.loadDeliveryGroups();
        }, 300);
    }

    async loadDeliveryGroups() {
        this.isLoading = true;
        try {
            const results = await getDeliveryGroups({ searchTerm: this.searchTerm });
            this.deliveryGroups = results.map(delivery => ({
                ...delivery,
                statusClass: this.getStatusClass(delivery.Status__c),
                showTrackButton: delivery.Status__c === 'In Transit',
                showMarkDelivered: delivery.Status__c === 'In Transit'
            }));
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading delivery groups', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleTrack(event) {
        const deliveryId = event.target.dataset.id;
        // Implement tracking logic
        this.showToast('Info', 'Tracking feature coming soon', 'info');
    }

    async handleMarkDelivered(event) {
        const deliveryId = event.target.dataset.id;
        try {
            this.isLoading = true;
            await markDeliveryAsCompleted({ deliveryGroupId: deliveryId });
            this.showToast('Success', 'Delivery marked as completed', 'success');
            await this.loadDeliveryGroups(); // Refresh the list
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to mark delivery as completed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleViewDetails(event) {
        const deliveryId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: deliveryId,
                objectApiName: 'Delivery_Group__c',
                actionName: 'view'
            }
        });
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
}