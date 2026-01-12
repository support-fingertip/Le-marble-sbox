import { LightningElement, api, track, wire } from 'lwc';
import getProducts from '@salesforce/apex/ProductController.getProducts';
import getProductCategories from '@salesforce/apex/ProductController.getProductCategories';
import createCartLineItem from '@salesforce/apex/ProductController.createCartLineItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AddCartLineItem extends LightningElement {
    @api recordId; // Cart Id from the record page
    @track showModal = false;
    @track products = [];
    @track productOptions = [];
    @track selectedProductId = '';
    @track selectedProduct = null;
    @track quantity = 1;
    @track uom = 'NOS';
    @track uomOptions = [
        { label: 'NOS', value: 'NOS' },
        { label: 'Box', value: 'Box' },
        { label: 'Carton', value: 'Carton' }
    ];
    @track discType = 'Percentage';
    @track discountTypeOptions = [
        { label: 'Percentage', value: 'Percentage' },
        { label: 'Amount', value: 'Amount' }
    ];
    @track discValue = 0;
    @track sqft = 0;
    @track sqm = 0;
    @track requiredSqft = 0;
    @track unitPrice = 0;
    @track priceSqft = 0;
    @track afterDiscPricePiece = 0;
    @track afterDiscPriceSqft = 0;
    @track totalPrice = 0;
    @track productImageUrl = '';
    @track productName = '';
    @track productCode = '';
    @track isTile = false;
    @track categories = [ { label: 'Select Category', value: 'select' } ];
    @track selectedCategory = 'select';
    @track searchQuery = '';
    @track searchResults = [];
    @track showSearchDropdown = false;
    @track searchTimeout;
    @track stockCount = 0;
    @track stockStatus = '';
    @track unitPriceAfterTax = '';
    @track pricePerSqft = '';
    @track description = '';
    @track roomType = ''; // Add room type field

    @wire(getProductCategories)
    wiredCategories({ error, data }) {
        if (data) {
            this.categories = [
                { label: 'Select Category', value: 'select' },
                ...data.map(category => ({ label: category, value: category }))
            ];
        }
    }

    @wire(getProducts)
    wiredProducts({ error, data }) {
        if (data) {
            this.products = data.map(product => ({
                ...product,
                quantity: 0,
                discount: 0,
                discType: 'Percentage',
                discValue: 0,
                totalPrice: 0,
                uom: 'NOS',
                sqft: 0,
                sqm: 0,
                requiredSqft: 0,
                unitPrice: product.MRP__c || 0,
                priceSqft: product.MRP__c || 0,
                afterDiscPricePiece: 0,
                afterDiscPriceSqft: 0,
                blocked: 0,
                imageUrl: this.extractImageUrl(product.Product_Image__c),
                isTile: product.Product_Category__c === 'TILES',
                sqftPerPiece: parseFloat(product.Sqft_Piece__c || '0'),
                stockCount: Number(product.In_Stock__c) || 0,
                stockStatus: Number(product.In_Stock__c) > 0 ? `In Stock (${product.In_Stock__c})` : 'Out of Stock'
            }));
            this.productOptions = this.products.map(prod => ({
                label: prod.Name,
                value: prod.Id
            }));
        }
    }

    extractImageUrl(richText) {
        if (!richText) return '';
        const div = document.createElement('div');
        div.innerHTML = richText;
        const img = div.querySelector('img');
        return img ? img.src : '';
    }

    openModal() {
        this.showModal = true;
        // Reset all fields
        this.selectedProductId = '';
        this.selectedProduct = null;
        this.quantity = 1;
        this.uom = 'NOS';
        this.discType = 'Percentage';
        this.discValue = 0;
        this.sqft = 0;
        this.sqm = 0;
        this.requiredSqft = 0;
        this.unitPrice = 0;
        this.priceSqft = 0;
        this.afterDiscPricePiece = 0;
        this.afterDiscPriceSqft = 0;
        this.totalPrice = 0;
        this.productImageUrl = '';
        this.productName = '';
        this.productCode = '';
        this.isTile = false;
        this.selectedCategory = 'select';
        this.searchQuery = '';
        this.searchResults = [];
        this.showSearchDropdown = false;
        this.description = '';
    }
    closeModal() {
        this.showModal = false;
    }

    handleCategorySelect(event) {
        this.selectedCategory = event.target.value;
        this.searchQuery = '';
        this.searchResults = [];
        this.showSearchDropdown = false;
        this.selectedProduct = null;
    }

    handleSearchInput(event) {
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        const searchQuery = event.target.value;
        this.searchQuery = searchQuery;
        if (!searchQuery) {
            this.showSearchDropdown = false;
            this.searchResults = [];
            return;
        }
        this.searchTimeout = setTimeout(() => {
            const query = searchQuery.toLowerCase();
            this.searchResults = this.products
                .filter(product => {
                    const matchesSearch = (product.Name && product.Name.toLowerCase().includes(query)) ||
                        (product.Product_Code__c && product.Product_Code__c.toLowerCase().includes(query));
                    if (this.selectedCategory && this.selectedCategory !== 'select') {
                        return matchesSearch && product.Product_Category__c === this.selectedCategory;
                    }
                    return matchesSearch;
                })
                .slice(0, 10);
            this.showSearchDropdown = this.searchResults.length > 0;
        }, 300);
    }

    handleSearchResultClick(event) {
        const productId = event.currentTarget.dataset.productId;
        const product = this.products.find(p => p.Id === productId);
        if (product) {
            this.selectedProductId = product.Id;
            this.selectedProduct = product;
            this.productImageUrl = product.imageUrl || 'https://www.levarusglobal.com/wp-content/uploads/2021/06/no-product-image.jpg';
            this.productName = product.Name;
            this.productCode = product.Product_Code__c;
            this.uom = product.UOM__c || 'NOS';
            this.unitPrice = product.MRP__c || 0;
            this.priceSqft = product.MRP__c || 0;
            this.isTile = product.isTile;
            this.sqft = 0;
            this.sqm = 0;
            this.requiredSqft = 0;
            this.quantity = 1;
            this.discType = 'Percentage';
            this.discValue = 0;
            this.afterDiscPricePiece = this.unitPrice;
            this.afterDiscPriceSqft = this.priceSqft;
            this.totalPrice = this.unitPrice;
            this.stockCount = product.stockCount;
            this.stockStatus = product.stockStatus;
            this.calculateAll();
            this.showSearchDropdown = false;
            this.searchQuery = '';
        }
    }

    handleUomChange(event) {
        this.uom = event.target.value;
    }
    handleQuantityChange(event) {
        let val = parseInt(event.target.value, 10);
        this.quantity = isNaN(val) || val < 1 ? 1 : val;
        if (this.selectedProduct && this.selectedProduct.isTile && !isNaN(this.selectedProduct.sqftPerPiece) && this.selectedProduct.sqftPerPiece > 0) {
            this.sqft = Number((this.quantity * this.selectedProduct.sqftPerPiece).toFixed(3));
            this.requiredSqft = this.sqft;
            this.sqm = (this.sqft * 0.092903).toFixed(2);
        }
        this.calculateAll();
    }
    incrementQuantity() {
        this.quantity = (parseInt(this.quantity, 10) || 1) + 1;
        this.calculateAll();
    }
    decrementQuantity() {
        this.quantity = Math.max(1, (parseInt(this.quantity, 10) || 1) - 1);
        this.calculateAll();
    }
    handleDiscTypeChange(event) {
        this.discType = event.target.value;
        this.discValue = 0;
        this.calculateAll();
    }
    handleDiscValueChange(event) {
        this.discValue = parseFloat(event.target.value) || 0;
        this.calculateAll();
    }
    handleSqftChange(event) {
        this.sqft = Number((parseFloat(event.target.value) || 0).toFixed(3));
        if (this.selectedProduct && !isNaN(this.selectedProduct.sqftPerPiece) && this.selectedProduct.sqftPerPiece > 0 && this.sqft > 0) {
            // Calculate quantity by dividing total sqft by sqft per piece
            this.quantity = Math.ceil(this.sqft / this.selectedProduct.sqftPerPiece);
            // Calculate final sqft based on the rounded up quantity
            this.requiredSqft = Number((this.quantity * this.selectedProduct.sqftPerPiece).toFixed(3));
            // Calculate sqm (1 sqft = 0.092903 sqm)
            this.sqm = (this.requiredSqft * 0.092903).toFixed(2);
        }
        this.calculateAll();
    }
    handleRequiredSqftChange(event) {
        this.requiredSqft = parseFloat(event.target.value) || 0;
        if (this.selectedProduct && this.selectedProduct.Product_Category__c === 'NATURAL STONE') {
            this.sqft = this.requiredSqft;
            this.sqm = (this.sqft * 0.092903).toFixed(2);
        } else if (this.selectedProduct && !isNaN(this.selectedProduct.sqftPerPiece) && this.selectedProduct.sqftPerPiece > 0 && this.requiredSqft > 0) {
            // Calculate quantity by dividing required sqft by sqft per piece and rounding up
            this.quantity = Math.ceil(this.requiredSqft / this.selectedProduct.sqftPerPiece);
            // Calculate actual sqft based on the rounded up quantity
            this.sqft = this.quantity * this.selectedProduct.sqftPerPiece;
            // Calculate sqm (1 sqft = 0.092903 sqm)
            this.sqm = (this.sqft * 0.092903).toFixed(2);
        }
        this.calculateAll();
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    handleRoomTypeChange(event) {
        this.roomType = event.target.value;
    }

    handleUnitPriceChange(event) {
        this.unitPrice = parseFloat(event.target.value) || 0;
        this.calculateAll();
    }

    calculateAll() {
        if (!this.selectedProduct) return;
        const isTile = this.selectedProduct.isTile;
        const isNaturalStone = this.selectedProduct.Product_Category__c === 'NATURAL STONE';
        const unitPrice = parseFloat(this.unitPrice) || 0;
        const taxPercent = parseFloat(this.selectedProduct.Tax__c) || 0;
        const sqftPerPiece = parseFloat(this.selectedProduct.sqftPerPiece) || 0;
        const quantity = parseInt(this.quantity, 10) || 0;
        const discType = this.discType;
        const discValue = parseFloat(this.discValue) || 0;
        const requiredSqft = parseFloat(this.requiredSqft) || 0;
        let unitPriceAfterTax = unitPrice;
        let pricePerSqft = unitPrice;
        let afterDiscPricePiece = unitPrice;
        let afterDiscPriceSqft = unitPrice;
        let afterDiscPrice = unitPrice;
        let totalPrice = 0;

        if (isNaturalStone) {
            // 1. For natural stone, NO TAX is applied - use unit price directly
            this.unitPriceAfterTax = unitPrice.toFixed(2);

            // 2. Calculate the price after discount, starting from the unit price (no tax)
            let afterDiscPrice = unitPrice; // Start with the unit price (no tax)
            if (discType === 'Percentage' && discValue > 0) {
                afterDiscPrice = unitPrice * (1 - discValue / 100);
            } else if (discType === 'Amount' && discValue > 0) {
                // The discount amount is applied to the unit price (no tax)
                afterDiscPrice = Math.max(0, unitPrice - discValue);
            }

            // 3. Set the final display value for the price per piece after discount.
            this.afterDiscPricePiece = afterDiscPrice.toFixed(2);

            // 4. Calculate the total price.
            const totalPrice = afterDiscPrice * requiredSqft;
            this.totalPrice = totalPrice.toFixed(2);

            // 5. Clear fields that are not applicable to Natural Stone.
            this.afterDiscPriceSqft = 0;
            this.pricePerSqft = '';
            return;
        }

        if (isTile) {
            // Tiles calculation
            unitPriceAfterTax = unitPrice * (1 + taxPercent / 100);
            pricePerSqft = sqftPerPiece > 0 ? unitPriceAfterTax / sqftPerPiece : 0;
            let discPriceSqft = pricePerSqft;
            if (discType === 'Percentage' && discValue > 0) {
                discPriceSqft = pricePerSqft * (1 - discValue / 100);
            } else if (discType === 'Amount' && discValue > 0) {
                // Amount discount directly reduces price per sqft
                discPriceSqft = pricePerSqft - discValue;
            }
            totalPrice = discPriceSqft * requiredSqft;
            this.unitPriceAfterTax = unitPriceAfterTax.toFixed(2);
            this.pricePerSqft = pricePerSqft.toFixed(2);
            this.afterDiscPriceSqft = discPriceSqft.toFixed(2);
            this.afterDiscPricePiece = 0;
            this.afterDiscPrice = 0;
            this.totalPrice = Number(totalPrice).toFixed(2);
            return;
        }

        // Other products
        unitPriceAfterTax = unitPrice * (1 + taxPercent / 100);
        afterDiscPricePiece = unitPriceAfterTax;
        if (discType === 'Percentage' && discValue > 0) {
            afterDiscPricePiece = unitPriceAfterTax * (1 - discValue / 100);
        } else if (discType === 'Amount' && discValue > 0) {
            afterDiscPricePiece = Math.max(unitPriceAfterTax - discValue, 0);
        }
        totalPrice = afterDiscPricePiece * quantity;
        this.unitPriceAfterTax = unitPriceAfterTax.toFixed(2);
        this.pricePerSqft = '';
        this.afterDiscPricePiece = afterDiscPricePiece.toFixed(2);
        this.afterDiscPriceSqft = 0;
        this.afterDiscPrice = 0;
        this.totalPrice = Number(totalPrice).toFixed(2);
    }

    get isTile() {
        return this.selectedProduct && this.selectedProduct.isTile;
    }

    get isNaturalStone() {
        return this.selectedProduct && this.selectedProduct.Product_Category__c === 'NATURAL STONE';
    }

    get isOtherProduct() {
        return this.selectedProduct && !this.selectedProduct.isTile && this.selectedProduct.Product_Category__c !== 'NATURAL STONE';
    }

    async handleAdd() {
        // Validation: require either quantity or sqft
        if (!this.selectedProductId || (!this.quantity && !this.sqft)) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please select a product and enter either Quantity or Sqft.',
                variant: 'error'
            }));
            return;
        }

        // Validation: require area/room type
        if (!this.roomType || this.roomType.trim() === '') {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please enter Area/Room Type before adding to cart.',
                variant: 'error'
            }));
            return;
        }

        let finalTotalPrice;
        if (this.isNaturalStone) {
            finalTotalPrice = this.totalPrice;
        } else {
            // Always use totalPrice = afterDiscPricePiece * quantity, as in cart.js
            finalTotalPrice = (parseFloat(this.afterDiscPricePiece) * this.quantity).toFixed(2);
        }
        
        const item = {
            id: this.selectedProduct.Id,
            name: this.selectedProduct.Name,
            code: this.selectedProduct.Product_Code__c,
            category: this.selectedProduct.Product_Category__c,
            quantity: this.quantity,
            unitPrice: this.isNaturalStone ? this.unitPrice : this.unitPriceAfterTax,
            priceSqft: this.pricePerSqft,
            discType: this.discType,
            discValue: this.discValue,
            uom: this.uom,
            sqft: this.isNaturalStone ? this.requiredSqft : this.sqft,
            sqm: this.sqm,
            afterDiscPricePiece: this.afterDiscPricePiece,
            afterDiscPriceSqft: this.afterDiscPriceSqft,
            totalPrice: finalTotalPrice,
            description: this.description,
            roomType: this.roomType, // Add room type to the item
            imageUrl: this.productImageUrl || 'https://www.levarusglobal.com/wp-content/uploads/2021/06/no-product-image.jpg',
            price: this.unitPrice,
            // For natural stone, explicitly indicate no tax
            isNaturalStone: this.isNaturalStone
        };

        try {
            await createCartLineItem({ cartId: this.recordId, item });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Cart Line Item added!',
                variant: 'success'
            }));
            this.closeModal();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        }
    }
}