import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import addToWishlist from '@salesforce/apex/WishlistController.addToWishlist';
import getWishlistItems from '@salesforce/apex/WishlistController.getWishlistItems';

export default class WishlistItem extends LightningElement {
    @api productId;
    @api opportunityId;
    @track isInWishlist = false;
    @track isLoading = false;

    @wire(CurrentPageReference)
    pageRef;

    connectedCallback() {
        console.log('=== WishlistItem Initialization ===');
        console.log('ProductId:', this.productId);
        console.log('Initial DealId:', this.opportunityId);

        // Try to get the opportunity ID from different sources
        if (!this.opportunityId && this.pageRef?.state) {
            this.opportunityId = this.pageRef.state.c__recordId || 
                                this.pageRef.state.recordId || 
                                this.pageRef.state.id;
            console.log('DealId from page reference:', this.opportunityId);
        }

        if (!this.productId) {
            console.warn('WishlistItem: Product ID is missing');
        }
        if (!this.opportunityId) {
            console.warn('WishlistItem: Deal ID is missing');
        }

        // Check if product is already in wishlist
        if (this.productId && this.opportunityId) {
            this.checkWishlistStatus();
        }
    }

    checkWishlistStatus() {
        getWishlistItems({ opportunityId: this.opportunityId })
            .then(result => {
                if (result) {
                    this.isInWishlist = result.some(item => item.Product__c === this.productId);
                    console.log('Wishlist status checked:', this.isInWishlist);
                }
            })
            .catch(error => {
                console.error('Error checking wishlist status:', error);
            });
    }

    get heartButtonClass() {
        return `heart-button ${this.isInWishlist ? 'active' : ''}`;
    }

    get heartPathClass() {
        return this.isInWishlist ? 'heart-path-filled' : 'heart-path';
    }

    handleAddToWishlist() {
        if (this.isLoading) return;
        
        console.log('=== Starting addToWishlist ===');
        console.log('ProductId:', this.productId);
        console.log('DealId:', this.opportunityId);
        
        if (!this.productId) {
            this.showError('Product ID is required for adding to wishlist');
            return;
        }

        if (!this.opportunityId) {
            this.showError('Deal ID is required for adding to wishlist');
            return;
        }

        // If item is already in wishlist, show message and return
        if (this.isInWishlist) {
            this.showToast('Info', 'This product is already in your wishlist', 'info');
            return;
        }

        this.isLoading = true;
        addToWishlist({
            productId: this.productId,
            opportunityId: this.opportunityId
        })
        .then(result => {
            console.log('Wishlist item created successfully:', result);
            this.isInWishlist = true;
            this.showSuccess('Product added to your wishlist');
            
            // Dispatch event to notify parent that item was added to wishlist
            this.dispatchEvent(new CustomEvent('wishlistadd', {
                detail: {
                    productId: this.productId
                }
            }));
        })
        .catch(error => {
            console.error('=== Error in addToWishlist ===');
            console.error('Error object:', error);
            console.error('Error body:', error.body);
            console.error('Error message:', error.body?.message || error.message);
            
            let errorMessage = 'Error adding to wishlist';
            if (error.body?.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            // If the item is already in wishlist, don't show error icon
            if (errorMessage.includes('already in your wishlist')) {
                this.showToast('Info', errorMessage, 'info');
                this.isInWishlist = true; // Ensure heart icon is filled
            } else {
                this.showError(errorMessage);
            }
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}