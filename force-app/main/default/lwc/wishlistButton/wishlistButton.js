import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWishlistItems from '@salesforce/apex/WishlistController.getWishlistItems';
import createCartFromWishlistItems from '@salesforce/apex/WishlistController.createCartFromWishlistItems';

export default class WishlistButton extends LightningElement {
    @api recordId;
    @api buttonLabel = 'View Wishlist';
    @api buttonVariant = 'brand';
    @api buttonIconName = 'utility:favorite';

    isModalOpen = false;
    isLoading = false;
    isProcessing = false;
    wishlistItems = [];
    selectedItems = new Set();
    error;
    freightCharge = 0;
    loadingCharge = 0;
    unloadingCharge = 0;

    discountTypeOptions = [
        { label: 'Percentage', value: 'Percentage' },
        { label: 'Amount', value: 'Amount' }
    ];

    get hasWishlistItems() {
        return this.wishlistItems && this.wishlistItems.length > 0;
    }

    get selectedCount() {
        return this.selectedItems.size;
    }

    get noItemsSelected() {
        return this.selectedItems.size === 0;
    }

    handleClick() {
        this.isModalOpen = true;
        this.loadWishlistItems();
    }

    loadWishlistItems() {
        if (!this.recordId) return;
        
        this.isLoading = true;
        getWishlistItems({ opportunityId: this.recordId })
            .then(result => {
                console.log('Debug - Raw wishlist items from server:', result);
                
                this.wishlistItems = result.map(item => {
                    const mappedItem = {
                        ...item,
                        isSelected: false,
                        quantity: 1,
                        sqft: item.Product__r.Product_Category__c === 'TILES' ? parseFloat(item.Product__r.Sqft_Piece__c || '0') : 0,
                        sqm: 0,
                        unitPrice: item.Product__r.MRP__c || 0,
                        priceSqft: item.Product__r.Price_Sqft__c || (item.Product__r.MRP__c && item.Product__r.Sqft_Piece__c ? (item.Product__r.MRP__c / item.Product__r.Sqft_Piece__c) : 0),
                        discType: 'Percentage',
                        discValue: 0,
                        afterDiscPricePiece: item.Product__r.MRP__c || 0,
                        afterDiscPriceSqft: item.Product__r.Price_Sqft__c || 0,
                        totalPrice: 0,
                        isTile: item.Product__r.Product_Category__c === 'TILES',
                        sqftPerPiece: parseFloat(item.Product__r.Sqft_Piece__c || '0')
                    };
                    
                    this.calculatePrices(mappedItem);
                    
                    console.log('Debug - Mapped wishlist item:', {
                        id: item.Id,
                        productName: item.Product__r?.Name,
                        category: item.Product__r?.Product_Category__c,
                        sqftPerPiece: mappedItem.sqftPerPiece,
                        rawSqftPerPiece: item.Product__r?.Sqft_Piece__c,
                        isTile: mappedItem.isTile,
                        totalPrice: mappedItem.totalPrice
                    });
                    
                    return mappedItem;
                });
            })
            .catch(error => {
                this.error = error;
                this.showToast('Error', 'Error loading wishlist items', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleItemSelection(event) {
        const itemId = event.target.dataset.id;
        const isSelected = event.target.checked;
        
        if (isSelected) {
            this.selectedItems.add(itemId);
        } else {
            this.selectedItems.delete(itemId);
        }
        
        this.wishlistItems = this.wishlistItems.map(item => ({
            ...item,
            isSelected: item.Id === itemId ? isSelected : item.isSelected
        }));
    }

    handleQuantityChange(event) {
        const itemId = event.target.dataset.id;
        const quantity = parseInt(event.target.value) || 0;
        const item = this.wishlistItems.find(i => i.Id === itemId);
        let updates = { quantity };
        if (item && item.isTile && !isNaN(item.sqftPerPiece) && item.sqftPerPiece > 0) {
            const sqft = Number((quantity * item.sqftPerPiece).toFixed(3));
            updates.sqft = sqft;
            updates.requiredSqft = sqft;
            updates.sqm = (sqft * 0.092903).toFixed(2);
        }
        this.updateWishlistItemFields(itemId, updates);
    }

    handleSqftChange(event) {
        const itemId = event.target.dataset.id;
        const sqft = Number((parseFloat(event.target.value) || 0).toFixed(3));
        const item = this.wishlistItems.find(i => i.Id === itemId);
        let updates = { sqft };
        if (item && item.isTile && !isNaN(item.sqftPerPiece) && item.sqftPerPiece > 0 && sqft > 0) {
            const quantity = Math.ceil(sqft / item.sqftPerPiece);
            updates.quantity = quantity;
            const finalSqft = Number((quantity * item.sqftPerPiece).toFixed(3));
            updates.requiredSqft = finalSqft;
            updates.sqm = (finalSqft * 0.092903).toFixed(2);
        }
        this.updateWishlistItemFields(itemId, updates);
    }

    handleRequiredSqftChange(event) {
        const itemId = event.target.dataset.id;
        const requiredSqft = Number((parseFloat(event.target.value) || 0).toFixed(3));
        const item = this.wishlistItems.find(i => i.Id === itemId);
        let updates = { requiredSqft };
        if (item && item.isTile && !isNaN(item.sqftPerPiece) && item.sqftPerPiece > 0 && requiredSqft > 0) {
            const quantity = Math.ceil(requiredSqft / item.sqftPerPiece);
            updates.quantity = quantity;
            const actualSqft = Number((quantity * item.sqftPerPiece).toFixed(3));
            updates.sqft = actualSqft;
            updates.sqm = (actualSqft * 0.092903).toFixed(2);
        }
        this.updateWishlistItemFields(itemId, updates);
    }

    handleDiscTypeChange(event) {
        const itemId = event.target.dataset.id;
        const discType = event.target.value;
        console.log('Discount type changed to:', discType); // Debug log
        this.updateWishlistItemFields(itemId, { discType });
        // Reset discount value when type changes
        this.updateWishlistItemFields(itemId, { discValue: 0 });
    }

    handleDiscValueChange(event) {
        const itemId = event.target.dataset.id;
        const discValue = parseFloat(event.target.value) || 0;
        this.updateWishlistItemFields(itemId, { discValue });
    }

    updateWishlistItemFields(itemId, updates) {
        const itemIndex = this.wishlistItems.findIndex(item => item.Id === itemId);
        if (itemIndex !== -1) {
            const updatedItem = { ...this.wishlistItems[itemIndex], ...updates };
            this.calculatePrices(updatedItem);
            this.wishlistItems[itemIndex] = updatedItem;
            this.wishlistItems = [...this.wishlistItems]; // Trigger reactivity
        }
    }

    calculatePrices(item) {
        const unitPrice = item.unitPrice || 0;
        const priceSqft = item.priceSqft || 0;
        const quantity = item.quantity || 1;
        const sqft = item.sqft || 0;
        const discType = item.discType || 'Percentage';
        const discValue = item.discValue || 0;
        let afterDiscPricePiece = unitPrice;
        let afterDiscPriceSqft = priceSqft;
        let totalPrice = 0;
        if (discType === 'Percentage' && discValue > 0) {
            const discountMultiplier = 1 - (discValue / 100);
            afterDiscPricePiece = unitPrice * discountMultiplier;
            afterDiscPriceSqft = priceSqft * discountMultiplier;
            totalPrice = afterDiscPricePiece * quantity;
        } else if (discType === 'Amount' && discValue > 0) {
            afterDiscPricePiece = unitPrice;
            afterDiscPriceSqft = priceSqft;
            totalPrice = (unitPrice * quantity) - discValue;
        } else {
            totalPrice = unitPrice * quantity;
        }
        item.afterDiscPricePiece = Number(afterDiscPricePiece).toFixed(2);
        item.afterDiscPriceSqft = Number(afterDiscPriceSqft).toFixed(2);
        item.totalPrice = Number(totalPrice).toFixed(2);
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

    handleConvertToCart() {
        if (this.selectedItems.size === 0) {
            this.showToast('Error', 'Please select items to convert to cart', 'error');
            return;
        }

        // Get selected items with their current state
        const selectedWishlistItems = this.wishlistItems.filter(item => this.selectedItems.has(item.Id));

        // Validate that all selected items have quantity greater than 0
        const itemsWithoutQuantity = selectedWishlistItems.filter(item => !item.quantity || item.quantity <= 0);
        if (itemsWithoutQuantity.length > 0) {
            this.showToast('Error', 'Please enter quantity for all selected items', 'error');
            return;
        }

        this.isProcessing = true;

        // Recalculate prices for all selected items
        selectedWishlistItems.forEach(item => this.calculatePrices(item));

        // Prepare cart items
        const cartItems = selectedWishlistItems.map(item => ({
            id: item.Product__c,
            category: item.Product__r.Product_Category__c,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            priceSqft: item.priceSqft,
            discType: item.discType,
            discValue: item.discValue,
            uom: item.uom,
            sqft: item.sqft || 0,
            sqm: item.sqm || 0,
            afterDiscPricePiece: parseFloat(item.afterDiscPricePiece),
            afterDiscPriceSqft: parseFloat(item.afterDiscPriceSqft),
            price: item.unitPrice,
            discount: item.discValue,
            totalPrice: parseFloat(item.totalPrice)
        }));

        console.log('Converting to cart with items:', cartItems);

        createCartFromWishlistItems({
            wishlistItemIds: Array.from(this.selectedItems),
            opportunityId: this.recordId,
            cartItems: cartItems,
            freightCharge: this.freightCharge,
            loadingCharge: this.loadingCharge,
            unloadingCharge: this.unloadingCharge
        })
        .then(() => {
            this.showToast('Success', 'Items converted to cart successfully', 'success');
            this.loadWishlistItems(); // Refresh the list
            this.closeModal();
        })
        .catch(error => {
            console.error('Error converting to cart:', error);
            this.showToast('Error', error.body?.message || 'Error converting items to cart', 'error');
        })
        .finally(() => {
            this.isProcessing = false;
        });
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedItems.clear();
        this.wishlistItems = this.wishlistItems.map(item => ({
            ...item,
            isSelected: false
        }));
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