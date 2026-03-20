import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class CartModal extends LightningElement {
    @api recordId;
    
    @wire(CurrentPageReference)
    pageRef;

    connectedCallback() {
        if (!this.recordId && this.pageRef?.state) {
            this.recordId = this.pageRef.state.c__recordId || 
                           this.pageRef.state.recordId || 
                           this.pageRef.state.id;
            console.log('CartModal: Record ID set from page reference:', this.recordId);
        }
        // Load cartItems from localStorage if not provided by parent
        if (!this._cartItems || this._cartItems.length === 0) {
            const savedCart = localStorage.getItem('selectedProducts');
            if (savedCart) {
                try {
                    this._cartItems = JSON.parse(savedCart);
                } catch (e) {
                    this._cartItems = [];
                }
            }
        }
    }
    
    @api 
    get cartItems() {
        return this._cartItems || [];
    }
    set cartItems(value) {
        if (value) {
            this._cartItems = value.map(item => {
                let unitPriceDisplay = 0;
                let afterDiscDisplay = 0;
                let lineTotalDisplay = 0;
                if (item.isNaturalStone) {
                    unitPriceDisplay = item.unitPrice || 0;
                    if (item.discType === 'Percentage') {
                        afterDiscDisplay = item.afterDiscPrice || 0;
                        lineTotalDisplay = parseFloat(item.afterDiscPrice || 0) * parseFloat(item.requiredSqft || 0);
                    } else if (item.discType === 'Amount') {
                        afterDiscDisplay = Math.max((parseFloat(item.unitPrice || 0) - parseFloat(item.discValue || 0)), 0);
                        lineTotalDisplay = afterDiscDisplay * parseFloat(item.requiredSqft || 0);
                    } else {
                        afterDiscDisplay = item.unitPrice || 0;
                        lineTotalDisplay = parseFloat(item.unitPrice || 0) * parseFloat(item.requiredSqft || 0);
                    }
                } else if (item.isTile) {
                    unitPriceDisplay = item.unitPriceAfterTax || 0;
                    afterDiscDisplay = item.afterDiscPriceSqft || 0;
                    lineTotalDisplay = parseFloat(item.afterDiscPriceSqft || 0) * parseFloat(item.requiredSqft || 0);
                } else {
                    unitPriceDisplay = item.unitPriceAfterTax || 0;
                    afterDiscDisplay = item.afterDiscPricePiece || 0;
                    lineTotalDisplay = parseFloat(item.afterDiscPricePiece || 0) * parseFloat(item.quantity || 0);
                }
                return {
                    ...item,
                    discountSymbol: item.discType === 'Percentage' ? '%' : '\u20b9',
                    unitPriceDisplay: unitPriceDisplay,
                    afterDiscDisplay: afterDiscDisplay,
                    lineTotalDisplay: lineTotalDisplay.toFixed(2)
                };
            });
            // Save to localStorage
            localStorage.setItem('selectedProducts', JSON.stringify(this._cartItems));
        } else {
            this._cartItems = [];
            localStorage.setItem('selectedProducts', JSON.stringify([]));
        }
    }
    _cartItems = [];
    
    @track freightCharge = 0;
    @track loadingCharge = 0;
    @track unloadingCharge = 0;

    get afterDiscPriceLabel() {
        const hasSqftItems = this._cartItems.some(item => item.sqft > 0);
        return hasSqftItems ? 'After Disc/Sqft(₹)' : 'After Disc/Price';
    }

    get hasItems() {
        return this.cartItems && this.cartItems.length > 0;
    }

    get subtotal() {
        return this.cartItems
            .reduce((sum, item) => sum + parseFloat(item.lineTotalDisplay || 0), 0)
            .toFixed(2);
    }

    get orderTotal() {
        // Calculate order total including all charges
        const total = parseFloat(this.subtotal) + 
                       parseFloat(this.freightCharge || 0) + 
                       parseFloat(this.loadingCharge || 0) + 
                       parseFloat(this.unloadingCharge || 0);
        return total.toFixed(2);
    }

    handleQuantityChange(event) {
        const itemId = event.target.dataset.id;
        let quantity = parseInt(event.target.value, 10);
        
        if (quantity < 1) quantity = 1;
        
        // Find the item and get its composite key
        const item = this.cartItems.find(item => item.id === itemId);
        const identifier = item && item.compositeKey ? item.compositeKey : itemId;
        
        this.dispatchEvent(new CustomEvent('quantitychange', {
            detail: {
                itemId: identifier,
                quantity
            }
        }));
    }

    handleIncrease(event) {
        const itemId = event.currentTarget.dataset.id;
        const item = this.cartItems.find(item => item.id === itemId);
        if (item) {
            const identifier = item.compositeKey || itemId;
            this.dispatchEvent(new CustomEvent('quantitychange', {
                detail: {
                    itemId: identifier,
                    quantity: item.quantity + 1
                }
            }));
        }
    }

    handleDecrease(event) {
        const itemId = event.currentTarget.dataset.id;
        const item = this.cartItems.find(item => item.id === itemId);
        if (item && item.quantity > 1) {
            const identifier = item.compositeKey || itemId;
            this.dispatchEvent(new CustomEvent('quantitychange', {
                detail: {
                    itemId: identifier,
                    quantity: item.quantity - 1
                }
            }));
        }
    }

    handleRemoveItem(event) {
        const itemId = event.currentTarget.dataset.id;
        // Find the item and get its composite key
        const item = this.cartItems.find(item => item.id === itemId);
        if (item && item.compositeKey) {
            this.dispatchEvent(new CustomEvent('removeitem', {
                detail: item.compositeKey
            }));
        } else {
            // Fallback to itemId if compositeKey is not available
            this.dispatchEvent(new CustomEvent('removeitem', {
                detail: itemId
            }));
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleFreightChargeChange(event) {
        this.freightCharge = parseFloat(event.target.value) || 0;
    }

    handleLoadingChargeChange(event) {
        this.loadingCharge = parseFloat(event.target.value) || 0;
    }

    handleUnloadingChargeChange(event) {
        this.unloadingCharge = parseFloat(event.target.value) || 0;
    }

    handleConfirm() {
        // Dispatch confirm event to parent component
        this.dispatchEvent(new CustomEvent('confirm', {
            detail: {
                items: this.cartItems,
                summary: {
                    freightCharge: this.freightCharge,
                    loadingCharge: this.loadingCharge,
                    unloadingCharge: this.unloadingCharge,
                    subtotal: this.subtotal,
                    orderTotal: this.orderTotal
                }
            }
        }));
    }

    // Add handler for wishlist events
    handleWishlistAdd(event) {
        const itemId = event.detail.productId;
        // Remove item from cart
        this.dispatchEvent(new CustomEvent('removeitem', {
            detail: itemId
        }));
        
        // Show success message
        this.dispatchEvent(new CustomEvent('showtoast', {
            detail: {
                title: 'Success',
                message: 'Item moved to wishlist',
                variant: 'success'
            }
        }));
    }

    isNaturalStone(item) {
        return item.category === 'NATURAL STONE';
    }
}