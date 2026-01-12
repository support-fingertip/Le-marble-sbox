import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getWishlistItems from '@salesforce/apex/WishlistController.getWishlistItems';
import removeFromWishlist from '@salesforce/apex/WishlistController.removeFromWishlist';
import createCartFromWishlistItems from '@salesforce/apex/WishlistController.createCartFromWishlistItems';

export default class WishlistView extends LightningElement {
    @api recordId;
    @api opportunityId;
    /** @deprecated Use opportunityId instead */
    @api leadId;
    @track wishlistItems = [];
    @track selectedItems = new Set();
    @track cartItems = new Map();
    @track isLoading = true;
    @track isProcessing = false;
    @track isModalOpen = false;
    @track error;
    @track showError = false;
    @track freightCharge = 0;
    @track loadingCharge = 0;
    @track unloadingCharge = 0;

    discountTypeOptions = [
        { label: 'None', value: 'None' },
        { label: 'Percentage', value: 'Percentage' },
        { label: 'Amount', value: 'Amount' }
    ];

    uomOptions = [
        { label: 'NOS', value: 'NOS' },
        { label: 'Box', value: 'Box' },
        { label: 'Carton', value: 'Carton' }
    ];

    @wire(CurrentPageReference)
    pageRef;

    connectedCallback() {
        this.initializeOpportunityId();
    }

    initializeOpportunityId() {
        if (this.recordId) {
            this.opportunityId = this.recordId;
            return;
        }
        
        if (this.pageRef?.state) {
            const urlId = this.pageRef.state.c__opportunityId || 
                         this.pageRef.state.recordId || 
                         this.pageRef.state.id;
            if (urlId) {
                this.opportunityId = urlId;
                return;
            }
        }
        
        if (!this.opportunityId) {
            this.setError('Configuration Error', 'No opportunity ID provided.');
        }
    }

    setError(title, message) {
        this.error = {
            title: title,
            message: message
        };
        this.showError = true;
    }

    clearError() {
        this.error = undefined;
        this.showError = false;
    }

    @wire(getWishlistItems, { opportunityId: '$opportunityId' })
    wiredWishlistItems({ error, data }) {
        this.isLoading = true;
        
        if (!this.opportunityId) {
            this.setError('Configuration Error', 'No opportunity ID provided.');
            this.isLoading = false;
            return;
        }

        if (data) {
            console.log('Received wishlist items for opportunity:', this.opportunityId);
            this.wishlistItems = data;
            this.clearError();
        } else if (error) {
            console.error('Error fetching wishlist items:', error);
            this.setError(
                'Error Loading Wishlist',
                error.body?.message || 'Unable to load wishlist items'
            );
            this.wishlistItems = [];
        }
        
        this.isLoading = false;
    }

    handleRemoveFromWishlist(event) {
        const wishlistItemId = event.target.dataset.id;
        if (!wishlistItemId) {
            console.error('No wishlist item ID provided for removal');
            return;
        }

        this.isLoading = true;
        
        removeFromWishlist({ wishlistItemId })
            .then(() => {
                this.wishlistItems = this.wishlistItems.filter(item => item.Id !== wishlistItemId);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Product removed from wishlist',
                    variant: 'success'
                }));
            })
            .catch(error => {
                console.error('Error removing wishlist item:', { wishlistItemId, error });
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Error removing item from wishlist',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasWishlistItems() {
        return Array.isArray(this.wishlistItems) && this.wishlistItems.length > 0;
    }

    handleItemSelection(event) {
        const itemId = event.target.dataset.id;
        if (event.target.checked) {
            this.selectedItems.add(itemId);
        } else {
            this.selectedItems.delete(itemId);
        }
    }

    get selectedCount() {
        return this.selectedItems.size;
    }

    get noItemsSelected() {
        return this.selectedItems.size === 0;
    }

    handleAddSelectedToCart() {
        if (this.selectedItems.size === 0) return;
        
        // Initialize cart items with selected wishlist items
        this.cartItems.clear();
        this.wishlistItems.forEach(item => {
            if (this.selectedItems.has(item.Id)) {
                const unitPrice = item.Product__r.MSP__c || 0;
                const priceSqft = item.Product__r.Price_Sqft__c || 0;
                this.cartItems.set(item.Id, {
                    ...item,
                    quantity: 1,
                    unitPrice: unitPrice,
                    priceSqft: priceSqft,
                    discType: 'Percentage', // Default to Percentage
                    discValue: 0,
                    afterDiscPricePiece: unitPrice,
                    afterDiscPriceSqft: priceSqft,
                    totalPrice: unitPrice,
                    uom: 'NOS',
                    sqft: 0,
                    sqm: 0,
                    isTile: item.Product__r.Product_Category__c === 'TILES'
                });
            }
        });
        
        this.isModalOpen = true;
    }

    get selectedWishlistItems() {
        return Array.from(this.cartItems.values());
    }

    get isInvalid() {
        return !this.selectedWishlistItems.every(item => 
            item.quantity > 0 && item.unitPrice >= 0
        );
    }

    handleQuantityChange(event) {
        const itemId = event.target.dataset.id;
        const quantity = parseInt(event.target.value) || 0;
        const item = this.cartItems.get(itemId);
        let updates = { quantity };
        if (item && item.isTile && !isNaN(item.Product__r.Sqft_Piece__c) && item.Product__r.Sqft_Piece__c > 0) {
            const sqftPerPiece = parseFloat(item.Product__r.Sqft_Piece__c);
            const sqft = Number((quantity * sqftPerPiece).toFixed(3));
            updates.sqft = sqft;
            updates.requiredSqft = sqft;
            updates.sqm = (sqft * 0.092903).toFixed(2);
        }
        this.updateCartItem(itemId, updates);
    }

    handleSqftChange(event) {
        const itemId = event.target.dataset.id;
        const sqft = Number((parseFloat(event.target.value) || 0).toFixed(3));
        const item = this.cartItems.get(itemId);
        let updates = { sqft };
        if (item && item.isTile && !isNaN(item.Product__r.Sqft_Piece__c) && item.Product__r.Sqft_Piece__c > 0 && sqft > 0) {
            const sqftPerPiece = parseFloat(item.Product__r.Sqft_Piece__c);
            const quantity = Math.ceil(sqft / sqftPerPiece);
            updates.quantity = quantity;
            const finalSqft = Number((quantity * sqftPerPiece).toFixed(3));
            updates.requiredSqft = finalSqft;
            updates.sqm = (finalSqft * 0.092903).toFixed(2);
        }
        this.updateCartItem(itemId, updates);
    }

    handleRequiredSqftChange(event) {
        const itemId = event.target.dataset.id;
        const requiredSqft = Number((parseFloat(event.target.value) || 0).toFixed(3));
        const item = this.cartItems.get(itemId);
        let updates = { requiredSqft };
        if (item && item.isTile && !isNaN(item.Product__r.Sqft_Piece__c) && item.Product__r.Sqft_Piece__c > 0 && requiredSqft > 0) {
            const sqftPerPiece = parseFloat(item.Product__r.Sqft_Piece__c);
            const quantity = Math.ceil(requiredSqft / sqftPerPiece);
            updates.quantity = quantity;
            const actualSqft = Number((quantity * sqftPerPiece).toFixed(3));
            updates.sqft = actualSqft;
            updates.sqm = (actualSqft * 0.092903).toFixed(2);
        }
        this.updateCartItem(itemId, updates);
    }

    handleUnitPriceChange(event) {
        const itemId = event.target.dataset.id;
        const unitPrice = parseFloat(event.target.value) || 0;
        this.updateCartItem(itemId, { unitPrice });
    }

    handlePriceSqftChange(event) {
        const itemId = event.target.dataset.id;
        const priceSqft = parseFloat(event.target.value) || 0;
        this.updateCartItem(itemId, { priceSqft });
    }

    handleDiscountTypeChange(event) {
        const itemId = event.target.dataset.id;
        const discType = event.target.value;
        console.log('Discount type changed to:', discType); // Debug log
        this.updateCartItem(itemId, { discType });
        // Reset discount value when type changes
        this.updateCartItem(itemId, { discValue: 0 });
    }

    handleDiscountValueChange(event) {
        const itemId = event.target.dataset.id;
        const discValue = parseFloat(event.target.value) || 0;
        this.updateCartItem(itemId, { discValue });
    }

    handleUOMChange(event) {
        const itemId = event.target.dataset.id;
        const UOM__c = event.target.value;
        this.updateCartItem(itemId, { UOM__c });
    }

    handleFreightChange(event) {
        this.freightCharge = parseFloat(event.target.value) || 0;
    }

    handleLoadingChange(event) {
        this.loadingCharge = parseFloat(event.target.value) || 0;
    }

    handleUnloadingChange(event) {
        this.unloadingCharge = parseFloat(event.target.value) || 0;
    }

    updateCartItem(itemId, updates) {
        const item = this.cartItems.get(itemId);
        if (!item) return;

        const updatedItem = { ...item, ...updates };
        // Calculate base prices with discount
        let afterDiscPricePiece = updatedItem.unitPrice;
        let afterDiscPriceSqft = updatedItem.priceSqft;
        const quantity = updatedItem.quantity || 0;
        const sqft = updatedItem.sqft || 0;
        const discType = updatedItem.discType || 'Percentage';
        const discValue = updatedItem.discValue || 0;
        // Discount logic
        let totalPrice = 0;
        if (discType === 'Percentage' && discValue > 0) {
            const discountMultiplier = 1 - (discValue / 100);
            afterDiscPricePiece = updatedItem.unitPrice * discountMultiplier;
            afterDiscPriceSqft = updatedItem.priceSqft * discountMultiplier;
            totalPrice = afterDiscPricePiece * quantity;
        } else if (discType === 'Amount' && discValue > 0) {
            afterDiscPricePiece = updatedItem.unitPrice;
            afterDiscPriceSqft = updatedItem.priceSqft;
            totalPrice = (updatedItem.unitPrice * quantity) - discValue;
        } else {
            totalPrice = updatedItem.unitPrice * quantity;
        }
        updatedItem.afterDiscPricePiece = Number(afterDiscPricePiece).toFixed(2);
        updatedItem.afterDiscPriceSqft = Number(afterDiscPriceSqft).toFixed(2);
        updatedItem.totalPrice = Number(totalPrice).toFixed(2);
        this.cartItems.set(itemId, updatedItem);
    }

    confirmAddToCart() {
        this.isProcessing = true;
        const cartItemsArray = this.selectedWishlistItems.map(item => ({
            id: item.Product__c,
            category: item.Product__r.Product_Category__c,
            quantity: item.quantity,
            uom: item.UOM__c,
            unitPrice: item.unitPrice,
            priceSqft: item.priceSqft,
            discType: item.discType,
            discValue: item.discValue,
            price: item.totalPrice
        }));

        createCartFromWishlistItems({ 
            wishlistItemIds: Array.from(this.selectedItems),
            opportunityId: this.opportunityId,
            cartItems: cartItemsArray,
            freightCharge: this.freightCharge,
            loadingCharge: this.loadingCharge,
            unloadingCharge: this.unloadingCharge
        })
        .then(() => {
            this.wishlistItems = this.wishlistItems.filter(
                item => !this.selectedItems.has(item.Id)
            );
            this.selectedItems.clear();
            this.cartItems.clear();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Items added to cart successfully',
                variant: 'success'
            }));
        })
        .catch(error => {
            console.error('Error adding items to cart:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Error adding items to cart',
                variant: 'error'
            }));
        })
        .finally(() => {
            this.isProcessing = false;
            this.isModalOpen = false;
        });
    }

    closeModal() {
        this.isModalOpen = false;
        this.cartItems.clear();
    }
}