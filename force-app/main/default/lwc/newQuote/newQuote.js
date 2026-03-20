import { LightningElement, track, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getProducts from '@salesforce/apex/NewQuoteController.getProducts';
import getPendingQuotes from '@salesforce/apex/NewQuoteController.getPendingQuotes';
import getPriceBookName from '@salesforce/apex/NewQuoteController.getPriceNames';
import getOpportunityItems from '@salesforce/apex/NewQuoteController.getOpportunityItems';
import getProductCategories from '@salesforce/apex/NewQuoteController.getProductCategories';
import getPBEntries from '@salesforce/apex/NewQuoteController.getPBEntries';
import createCart from '@salesforce/apex/NewQuoteController.createCart';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

export default class NewQuote extends NavigationMixin(LightningElement) {
    @api recordId; // This will store the Customer Id
    @track selectedCategory = '';
    @track selectedPB = '';
    pbEntries = [];
    pbEntryMap = new Map();
    pbEntryIdMap = new Map();
    @track isDropdownOpen = false;
    @track isLoading = false;
    @track searchQuery = '';
    @track products = []; // Initialize products array
    @track selectedProducts = []; // Initialize selectedProducts array
    @track showCartModal = false; // Initialize showCartModal
    @track error;
    @track displayedProducts = []; // Track currently displayed products
    pendingQuoteId = null;

    // Track the additional fields for cart summary
    @track freightCharge = 0;
    @track loadingCharge = 0;
    @track unloadingCharge = 0;
    @track orderTotal = 0;

    get isCategoryDisabled() {
        return !this.selectedPB;   // disabled when no Pricebook selected
    }

    priceNames=[{ label: 'Select PriceBook', value: 'select' }];
    categories = [
        { label: 'Select Category', value: 'select' }
    ];

    // Discount Type options
    discountTypeOptions = [
        { label: 'Percentage', value: 'Percentage' },
        { label: 'Amount', value: 'Amount' }
    ];

    @track searchResults = [];
    @track showSearchDropdown = false;
    @track searchTimeout;

    @wire(CurrentPageReference)
    pageRef;

    connectedCallback() {
        this.initializeRecordId();

    if(this.recordId){
        this.checkPendingQuotes();   // 👈 trigger on component load
    }

        this.selectedProducts = [];
        localStorage.removeItem('selectedProducts');

        // Load cart from localStorage if available
        const savedCart = localStorage.getItem('selectedProducts');
        if (savedCart) {
            try {
                this.selectedProducts = JSON.parse(savedCart);
            } catch (e) {
                this.selectedProducts = [];
            }
        }

        // Add click event listener to close dropdown when clicking outside
        this.handleClickOutside = () => {
            if (this.isDropdownOpen) {
                this.isDropdownOpen = false;
                const options = this.template.querySelector('.options');
                const arrow = this.template.querySelector('.arrow');
                if (options && arrow) {
                    options.classList.remove('show');
                    arrow.classList.remove('open');
                }
            }
        };

        window.addEventListener('click', this.handleClickOutside);

        // Add click event listener to close search dropdown when clicking outside
        this.handleClickOutsideSearch = (event) => {
            const searchContainer = this.template.querySelector('.search-container');
            if (searchContainer && !searchContainer.contains(event.target)) {
                this.closeSearchDropdown();
            }
        };

        window.addEventListener('click', this.handleClickOutsideSearch);
    }

    

    initializeRecordId() {
        console.log('Initializing Record ID');
        
        // Try URL parameters first
        const urlParams = new URLSearchParams(window.location.search);
        const customerId = urlParams.get('c__recordId');
        
        if (customerId) {
            this.recordId = customerId;
            console.log('Customer ID set from URL:', this.recordId);
            return;
        }

        // Try page reference state
        if (this.pageRef?.state) {
            const pageRecordId = this.pageRef.state.c__recordId || 
                               this.pageRef.state.recordId || 
                               this.pageRef.state.id;
            if (pageRecordId) {
                this.recordId = pageRecordId;
                console.log('Customer ID set from page reference:', this.recordId);
                return;
            }
        }

        console.log('No Customer ID found in URL parameters or page reference');
    }

    checkPendingQuotes() {
    getPendingQuotes({ oppId: this.recordId })
    .then(result => {
        if(result && result.length > 0){

            this.pendingQuoteId = result[0].Id;

            // 🔥 Show warning popup
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Approval Pending',
                    message: 'A Quote is already in approval stage. Redirecting...',
                    variant: 'warning',
                    mode: 'sticky'
                })
            );

            // 🔥 Redirect automatically to Quote record page
            setTimeout(() => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.pendingQuoteId,
                        objectApiName: 'Quote',
                        actionName: 'view'
                    }
                });
            }, 2000); // 2 sec delay so toast is visible
        }
    })
    .catch(err => console.error('Pending Quote Check Failed → ', err));
    }


    disconnectedCallback() {
        // Remove event listener when component is destroyed
        if (this.handleClickOutside) {
            window.removeEventListener('click', this.handleClickOutside);
        }
        if (this.handleClickOutsideSearch) {
            window.removeEventListener('click', this.handleClickOutsideSearch);
        }
    }
        @wire(getPriceBookName)
    wiredPriceNames({ error, data }) {
        if (data) {
            console.log('Pricebook Names fetched:', data);
            this.priceNames = [
                { label: 'Select Pricebook', value: 'select' },
                ...data.map(priceName => ({
                    label: priceName,
                    value: priceName
                }))
            ];
        } else if (error) {
            this.error = error;
            console.error('Error fetching priceNames:', error);
        }
    }


    @wire(getProductCategories)
    wiredCategories({ error, data }) {
        if (data) {
            console.log('Categories fetched:', data);
            this.categories = [
                { label: 'Select Category', value: 'select' },
                ...data.map(category => ({
                    label: category,
                    value: category
                }))
            ];
        } else if (error) {
            this.error = error;
            console.error('Error fetching categories:', error);
        }
    }

    extractImageUrl(richText) {
        if (!richText) return '';
        const div = document.createElement('div');
        div.innerHTML = richText;
        const img = div.querySelector('img');
        return img ? img.src : '';
    }

    @wire(getProducts)
    wiredProducts({ error, data }) {
        if (data) {
            console.log('Raw product data:', data); // Log the raw product data for debugging
            this.products = data.map(product => {
                const isTile = product.Product_Category__c === 'TILES';
 ///               const unitPrice = product.MRP__c || 0;
  //              const taxPercent = product.Tax__c || 0;
   //             const sqftPerPiece = parseFloat(product.Sqft_Piece__c || '0');
                let unitPriceAfterTax = '';
                // Do not pre-calculate pricePerSqft here; let calculatePrices handle it
              //  unitPrice: 0,
              //  priceSqft: 0,
                return {
                ...product,
                quantity: 0,
                discount: 0,
                discType: 'Percentage',
                discValue: 0,
                totalPrice: 0,
                sqft: 0,
                sqm: 0,
                requiredSqft: 0,
                unitPrice:  0,
                priceSqft:  0,
                afterDiscPricePiece: 0,
                afterDiscPriceSqft: 0,
                blocked: 0,
                imageUrl: this.extractImageUrl(product.Product_Image__c),
                    isTile,
                    unitPriceAfterTax,
                    // pricePerSqft will be set in calculatePrices
                    isNaturalStone: product.Product_Category__c === 'NATURAL STONE',
                sqftPerPiece: parseFloat(product.Sqft_Piece__c || '0'),
                inStock: Number(product.In_Stock__c) > 0,
                stockCount: Number(product.In_Stock__c) || 0,
                stockStatusText: Number(product.In_Stock__c) > 0 ? `In Stock (${product.In_Stock__c})` : 'Out of Stock',
                    roomType: '',
                    description: '',
                     PricebookEntry: ''
                };
            });
            this.displayedProducts = [];
        } else if (error) {
            this.error = error;
            console.error('Error fetching products:', error);
        }
    }

    get spinnerClass() {
        return `loading-spinner ${this.isLoading ? '' : 'hidden'}`;
    }

    get showProducts() {
        // Keep any other logic you need but don't use this to control search visibility
        return this.selectedCategory !== '' && this.selectedCategory !== 'select';
    }

    get filteredProducts() {
        return this.displayedProducts;
    }

    get selectedCategoryLabel() {
        const category = this.categories.find(cat => cat.value === this.selectedCategory);
        return category ? category.label : 'Select Category';
    }

    get showCartButton() {
        return this.filteredProducts.some(product => product.quantity > 0);
    }

    handleDropdownClick(event) {
        event.stopPropagation(); // Prevent event bubbling
        this.isDropdownOpen = !this.isDropdownOpen;
        
        // Toggle the options visibility
        const options = this.template.querySelector('.options');
        const arrow = this.template.querySelector('.arrow');
        
        if (this.isDropdownOpen) {
            options.classList.add('show');
            arrow.classList.add('open');
        } else {
            options.classList.remove('show');
            arrow.classList.remove('open');
        }
    }
    handlePBSelect(event) {
         this.selectedProducts = [];
            localStorage.removeItem('selectedProducts');
        this.selectedPB = event.target.value;
       
        this.loadOLIFromOpportunity();

        // Clear search results when category changes
        this.searchResults = [];
        this.showSearchDropdown = false;
        getPBEntries({ pbName: this.selectedPB })
        .then(result => {
            console.log('Pricebook Entries:', result);
                this.pbEntryMap = new Map();
                 this.pbEntryIdMap = new Map();
            result.forEach(entry => {
                this.pbEntryMap.set(entry.Product2Id, entry.UnitPrice);
                this.pbEntryIdMap.set(entry.Product2Id, entry.Id);
            });
  console.log('pbEntryIdMap map:', JSON.stringify(this.pbEntryIdMap)); 
            // Update prices in products list
            this.updateProductUnitPrices();
        })
        .catch(error => {
            console.error(error);
        });
        
        // If there's an active search, refilter the results
        if (this.searchQuery) {
            this.handleSearchInput({ target: { value: this.searchQuery } });
        }
    }

    loadOLIFromOpportunity() {
    if (!this.recordId || !this.selectedPB) return;

    getOpportunityItems({ oppId: this.recordId, pricebookName: this.selectedPB })
    .then(data => {
        if (data.length === 0) {
            console.log("No OLI found for this pricebook");
            return;
        }

        console.log("OLI Loaded:", data);

        data.forEach(item => {
            const compositeKey = `${item.Product2Id}_${item.Description || 'default'}`;

            const cartItem = {
                id: item.Product2Id,
                compositeKey,
                name: item.Product2.Name,
                code: item.Product2.Product_Code__c,
                category: item.Product2.Product_Category__c,
                quantity: item.Quantity,
                unitPrice: item.UnitPrice,
                afterDiscPricePiece: item.UnitPrice - (item.Discount || 0),
                totalPrice: item.TotalPrice,
                description: item.Description,
                discType: item.Discount > 0 ? 'Amount' : 'Percentage',
                discValue: item.Discount || 0,
                roomType: '',
                requiredSqft: 0,
                pricePerSqft: 0,
                afterDiscPriceSqft: 0,
                sqft: 0, sqm: 0,
                PricebookEntry: item.PricebookEntryId
            };

            this.selectedProducts = [...this.selectedProducts, cartItem];
        });

        this.saveCartToLocalStorage();
    })
    .catch(error => console.error("Failed to Fetch OLI:", error));
}


    updateProductUnitPrices() {
    if (!this.products || !this.pbEntryMap) return;

    this.products = this.products.map(product => {
        const newUnitPrice =
            this.pbEntryMap.get(product.Id) || 0; 
            const newUnitPb =
            this.pbEntryIdMap.get(product.Id) || ''; 
           console.log('pbEntryIdMap Entries:', newUnitPb);  
        return {
            ...product,
            unitPrice: newUnitPrice,
            priceSqft: newUnitPrice, // if needed
            totalPrice: product.quantity * newUnitPrice,
            PricebookEntry: newUnitPb
        };
    });
console.log(JSON.stringify( this.products));
    // Reset displayedProducts
  //  this.displayedProducts = [...this.products];
    }


    handleCategorySelect(event) {
        this.selectedCategory = event.target.value;
        
        // Clear search results when category changes
        this.searchResults = [];
        this.showSearchDropdown = false;
        
        // If there's an active search, refilter the results
        if (this.searchQuery) {
            this.handleSearchInput({ target: { value: this.searchQuery } });
        }
    }

    
    handleQuantityChange(event) {
        const productId = event.target.dataset.productId;
        const quantity = parseInt(event.target.value) || 0;
        this.updateProduct(productId, 'quantity', quantity);

        // Find the product and update sqft/requiredSqft/sqm if it's a tile
        const product = this.products.find(p => p.Id === productId);
        if (product && product.isTile && !isNaN(product.sqftPerPiece) && product.sqftPerPiece > 0) {
            const sqft = Number((quantity * product.sqftPerPiece).toFixed(3));
            this.updateProduct(productId, 'sqft', sqft);
            this.updateProduct(productId, 'requiredSqft', sqft);
            this.updateProduct(productId, 'sqm', (sqft * 0.092903).toFixed(2));
        }
    }

    handleDiscTypeChange(event) {
        try {
        const productId = event.target.dataset.productId;
        const discType = event.target.value;
            
            // Update only if value has changed
            const product = this.products.find(p => p.Id === productId);
            if (product && product.discType !== discType) {
        this.updateProduct(productId, 'discType', discType);
                
                if (product.isNaturalStone) {
                    this.calculateNaturalStonePrice(productId);
                } else {
                    this.calculatePrices(this.products.findIndex(p => p.Id === productId));
                }
            }
        } catch (error) {
            console.error('Error in handleDiscTypeChange:', error);
        }
    }

    handleDiscValueChange(event) {
        try {
        const productId = event.target.dataset.productId;
        const discValue = parseFloat(event.target.value) || 0;
            
            // Update only if value has changed
            const product = this.products.find(p => p.Id === productId);
            if (product && product.discValue !== discValue) {
        this.updateProduct(productId, 'discValue', discValue);
                
                if (product.isNaturalStone) {
                    this.calculateNaturalStonePrice(productId);
                } else {
                    this.calculatePrices(this.products.findIndex(p => p.Id === productId));
                }
            }
        } catch (error) {
            console.error('Error in handleDiscValueChange:', error);
        }
    }

    handleSqftChange(event) {
        const productId = event.target.dataset.productId;
        const sqft = Number((parseFloat(event.target.value) || 0).toFixed(3));
        
        // Update sqft
        this.updateProduct(productId, 'sqft', sqft);
        
        // Calculate and update sqm (1 sqft = 0.092903 sqm)
        const sqm = sqft * 0.092903;
        this.updateProduct(productId, 'sqm', sqm.toFixed(2));

        // Calculate quantity based on Sqft/Piece
        const product = this.products.find(p => p.Id === productId);
        
        if (product && !isNaN(product.sqftPerPiece) && product.sqftPerPiece > 0 && sqft > 0) {
            // Calculate quantity by dividing total sqft by sqft per piece
            const quantity = Math.ceil(sqft / product.sqftPerPiece);
            this.updateProduct(productId, 'quantity', quantity);
            
            // Calculate final sqft based on the rounded up quantity
            const finalSqft = Number((quantity * product.sqftPerPiece).toFixed(3));
            this.updateProduct(productId, 'requiredSqft', finalSqft);
        }
    }

    updateProduct(productId, field, value) {
        const productIndex = this.products.findIndex(p => p.Id === productId);
        
        if (productIndex !== -1) {
            this.products[productIndex][field] = value;
            this.calculatePrices(productIndex);
            this.products = [...this.products]; // Trigger reactivity
        }
    }

    calculatePrices(productIndex) {
        const product = this.products[productIndex];
        
        if (product.isNaturalStone) {
            // Natural Stone calculation
            const unitPrice = parseFloat(product.unitPrice) || 0;
            const requiredSqft = parseFloat(product.requiredSqft) || 0;
            const discType = product.discType || 'Percentage';
            const discValue = parseFloat(product.discValue) || 0;
            let afterDiscPrice = unitPrice;
            let totalPrice = unitPrice * requiredSqft;
            if (discType === 'Percentage' && discValue > 0) {
                afterDiscPrice = unitPrice * (1 - discValue / 100);
                totalPrice = afterDiscPrice * requiredSqft;
            } else if (discType === 'Amount' && discValue > 0) {
                // For amount, reduce from unit price
                afterDiscPrice = Math.max(unitPrice - discValue, 0);
                totalPrice = afterDiscPrice * requiredSqft;
            }
            product.afterDiscPrice = afterDiscPrice.toFixed(2);
            product.totalPrice = totalPrice.toFixed(2);
            this.products = [...this.products];
            return;
        }

        // For TILES
        if (product.isTile) {
            const unitPrice = parseFloat(product.unitPrice) || 0;
            const taxPercent = parseFloat(product.Tax__c) || 0;
            const sqftPerPiece = parseFloat(product.sqftPerPiece) || 0;
            const finalSqft = parseFloat(product.requiredSqft) || 0;
            const quantity = parseFloat(product.quantity) || 0;
            const discType = product.discType || 'Percentage';
            const discValue = parseFloat(product.discValue) || 0;

            // 1. Unit Price After Tax
            const unitPriceAfterTax = unitPrice * (1 + taxPercent / 100);

            // 2. Price per Sqft (rounded for both UI and calculation)
            let pricePerSqft = 0;
            if (sqftPerPiece > 0) {
                pricePerSqft = parseFloat((unitPriceAfterTax / sqftPerPiece).toFixed(2));
            }

            let afterDiscPriceSqft = pricePerSqft;
            if (discType === 'Percentage' && discValue > 0) {
                afterDiscPriceSqft = parseFloat((pricePerSqft * (1 - discValue / 100)).toFixed(2));
            } else if (discType === 'Amount' && discValue > 0) {
                // Amount discount directly reduces price per sqft
                afterDiscPriceSqft = parseFloat((pricePerSqft - discValue).toFixed(2));
            }

            // 3. Total Amount (use the after discount price per sqft)
            const totalPrice = parseFloat((afterDiscPriceSqft * finalSqft).toFixed(2));

            product.unitPriceAfterTax = unitPriceAfterTax.toFixed(2);
            product.pricePerSqft = pricePerSqft.toFixed(2); // always show original after-tax per sqft
            product.afterDiscPriceSqft = afterDiscPriceSqft.toFixed(2); // always from original
            product.totalPrice = totalPrice.toFixed(2);

            this.products = [...this.products];
            return;
        }

        // For OTHER CATEGORIES
        const unitPrice = parseFloat(product.unitPrice) || 0;
        const taxPercent = parseFloat(product.Tax__c) || 0;
        const quantity = parseFloat(product.quantity) || 0;
        const discType = product.discType || 'Percentage';
        const discValue = parseFloat(product.discValue) || 0;
        // 1. Unit Price After Tax
        const unitPriceAfterTax = unitPrice * (1 + taxPercent / 100);
        // 2. Discounted price per piece
        let afterDiscPricePiece = unitPriceAfterTax;
        if (discType === 'Percentage' && discValue > 0) {
            afterDiscPricePiece = unitPriceAfterTax * (1 - discValue / 100);
        } else if (discType === 'Amount' && discValue > 0) {
            afterDiscPricePiece = Math.max(unitPriceAfterTax - discValue, 0);
        }
        // 3. Total
        const totalPrice = afterDiscPricePiece * quantity;
        product.unitPriceAfterTax = unitPriceAfterTax.toFixed(2);
        product.afterDiscPricePiece = afterDiscPricePiece.toFixed(2);
        product.totalPrice = totalPrice.toFixed(2);
        this.products = [...this.products];
    }

    get isDefaultSelected() {
        return !this.selectedCategory;
    }

    get isMarblesSelected() {
        return this.selectedCategory === 'Italian Marbles';
    }

    handleSearch(event) {
        console.log('Search query:', event.target.value); // Debug log
        this.searchQuery = event.target.value;
    }

    handleImageError(event) {
        event.target.src = 'https://www.levarusglobal.com/wp-content/uploads/2021/06/no-product-image.jpg';
    }

    handleAddToCart(event) {
        const productId = event.currentTarget.dataset.productId;
        const product = this.products.find(p => p.Id === productId);
        
        // Validate that room type is provided
        if (!product.roomType || product.roomType.trim() === '') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please enter Area/Room Type before adding to cart',
                    variant: 'error'
                })
            );
            return;
        }
        
        if (product && (product.quantity > 0 || product.sqft > 0 || (product.isNaturalStone && product.requiredSqft > 0))) {
            let totalPrice;
            let cartItem = {};
            
            // Create a composite unique key for the cart item
            const compositeKey = `${product.Id}_${product.roomType || 'default'}_${product.description || 'default'}`;
            
            // Check if this exact combination already exists in cart
            const existingItemIndex = this.selectedProducts.findIndex(item => item.compositeKey === compositeKey);
            
            if (existingItemIndex !== -1) {
                // Product already exists in cart - show error message
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Product already in cart. Please remove existing item first.',
                        variant: 'error'
                    })
                );
                return;
            }
            
            if (product.isNaturalStone) {
                totalPrice = product.unitPrice * product.requiredSqft;
                cartItem = {
                    id: product.Id,
                    compositeKey: compositeKey, // Add composite key for unique identification
                    name: product.Name,
                    code: product.Product_Code__c,
                    category: product.Product_Category__c,
                    quantity: product.quantity,
                    unitPrice: Number(product.unitPrice), // for Unit_Price__c
                    pricePerSqft: 0,
                    requiredSqft: product.requiredSqft, // for Sqft__c
                    afterDiscPriceSqft: 0,
                    afterDiscPricePiece: 0,
                    afterDiscPrice: Number(product.afterDiscPrice), // for After_Disc_Price__c
                    totalPrice: Number(totalPrice).toFixed(2),
                    description: product.description,
                    uom: product.uom,
                    sqft: product.requiredSqft,
                    sqm: product.sqm,
                    imageUrl: product.imageUrl || 'https://www.levarusglobal.com/wp-content/uploads/2021/06/no-product-image.jpg',
                    roomType: product.roomType,
                    discType: product.discType,
                    discValue: product.discValue,
                    isNaturalStone: product.isNaturalStone,
                    isTile: product.isTile,
                    stockCount: product.stockCount,
                    inStock: product.inStock,
                    PricebookEntry: product.PricebookEntry
                };
            } else if (product.isTile) {
                totalPrice = product.afterDiscPriceSqft * product.requiredSqft;
                cartItem = {
                    id: product.Id,
                    compositeKey: compositeKey, // Add composite key for unique identification
                    name: product.Name,
                    code: product.Product_Code__c,
                    category: product.Product_Category__c,
                    quantity: product.quantity,
                    unitPriceAfterTax: Number(product.unitPriceAfterTax),
                    pricePerSqft: Number(product.pricePerSqft),
                    requiredSqft: product.requiredSqft,
                    afterDiscPriceSqft: Number(product.afterDiscPriceSqft),
                    afterDiscPricePiece: 0,
                    afterDiscPrice: 0,
                    totalPrice: Number(totalPrice).toFixed(2),
                    description: product.description,
                    uom: product.uom,
                    sqft: product.requiredSqft,
                    sqm: product.sqm,
                    imageUrl: product.imageUrl || 'https://www.levarusglobal.com/wp-content/uploads/2021/06/no-product-image.jpg',
                    roomType: product.roomType,
                    discType: product.discType,
                    discValue: product.discValue,
                    isNaturalStone: product.isNaturalStone,
                    isTile: product.isTile,
                    stockCount: product.stockCount,
                    inStock: product.inStock,
                     PricebookEntry: product.PricebookEntry
                };
                console.log('Cart item for Salesforce (TILE):', cartItem);
            } else {
                totalPrice = product.afterDiscPricePiece * product.quantity;
                cartItem = {
                id: product.Id,
                compositeKey: compositeKey, // Add composite key for unique identification
                name: product.Name,
                code: product.Product_Code__c,
                category: product.Product_Category__c,
                quantity: product.quantity,
                unitPrice: product.unitPrice,
                    unitPriceAfterTax: Number(product.unitPriceAfterTax),
                    pricePerSqft: 0,
                    requiredSqft: 0,
                    afterDiscPriceSqft: 0,
                    afterDiscPricePiece: product.afterDiscPricePiece, // for After_Disc_Price_Piece__c
                    afterDiscPrice: 0,
                    totalPrice: Number(totalPrice).toFixed(2),
                    description: product.description,
                    uom: product.uom,
                    sqft: 0,
                    sqm: product.sqm,
                    imageUrl: product.imageUrl || 'https://www.levarusglobal.com/wp-content/uploads/2021/06/no-product-image.jpg',
                    roomType: product.roomType,
                discType: product.discType,
                discValue: product.discValue,
                    isNaturalStone: product.isNaturalStone,
                    isTile: product.isTile,
                    stockCount: product.stockCount,
                    inStock: product.inStock,
                     PricebookEntry: product.PricebookEntry
                };
            }
            
            console.log('Adding to cart:', cartItem);
            
            // Add as new cart item (no merging)
            this.selectedProducts = [...this.selectedProducts, cartItem];
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Product added to cart',
                    variant: 'success'
                })
            );
        } else {
            // Show error toast if neither quantity nor sqft is provided
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please enter either Quantity or Sqft before adding to cart',
                    variant: 'error'
                })
            );
        }
        this.saveCartToLocalStorage();
    }

    handleViewCart() {
        console.log('View cart clicked');
        console.log('Selected products:', this.selectedProducts);
        this.showCartModal = true;
    }

    handleCloseModal() {
        this.showCartModal = false;
    }

    handleRemoveFromCart(event) {
        const itemCompositeKey = event.detail;
        console.log('Removing item with composite key:', itemCompositeKey);
        
        // Remove only the specific item using composite key
        this.selectedProducts = this.selectedProducts.filter(item => item.compositeKey !== itemCompositeKey);
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Item removed from cart',
                variant: 'success'
            })
        );
        this.saveCartToLocalStorage();
    }

    // Handler for cart summary field changes
    handleFreightChargeChange(event) {
        this.freightCharge = parseFloat(event.detail) || 0;
    }

    handleLoadingChargeChange(event) {
        this.loadingCharge = parseFloat(event.detail) || 0;
    }

    handleUnloadingChargeChange(event) {
        this.unloadingCharge = parseFloat(event.detail) || 0;
    }

    async handleConfirm(event) {
        try {
            console.log('handleConfirm called, current recordId:', this.recordId);
            
            // Double-check URL parameters and page reference
            const urlParams = new URLSearchParams(window.location.search);
            const dealIdFromUrl = urlParams.get('c__recordId');
            const dealIdFromPageRef = this.pageRef?.state?.c__recordId || 
                                    this.pageRef?.state?.recordId || 
                                    this.pageRef?.state?.id;
            
            console.log('Deal ID from URL:', dealIdFromUrl);
            console.log('Deal ID from page reference:', dealIdFromPageRef);

            // If recordId is not set but available in URL or page reference, set it
            if (!this.recordId) {
                if (dealIdFromUrl) {
                    this.recordId = dealIdFromUrl;
                } else if (dealIdFromPageRef) {
                    this.recordId = dealIdFromPageRef;
                }
                console.log('Setting recordId from available sources:', this.recordId);
            }

            if (!this.recordId) {
                console.error('No Deal ID available for cart creation');
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No Deal ID found. Please start from a Deal record.',
                        variant: 'error'
                    })
                );
                return;
            }

            if (this.selectedProducts.length === 0) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Please add products to cart before confirming.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Show loading toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Creating Cart',
                    message: 'Please wait while we create your cart...',
                    variant: 'info'
                })
            );

            // Get cart summary values from the modal
            const { freightCharge, loadingCharge, unloadingCharge,orderTotal } = event.detail.summary || {};

            // Prepare cart items with only the necessary data to minimize payload size
            const cartItems = this.selectedProducts.map(item => {
                return {
                    id: item.id,
                    category: item.category,
                    quantity: item.quantity,
                    unitPriceAfterTax: item.unitPriceAfterTax, // after-tax value for tiles/other products
                    pricePerSqft: item.pricePerSqft,           // after-tax per sqft for tiles
                    unitPrice: item.unitPrice,                 // for natural stone
                    priceSqft: item.priceSqft,                 // fallback
                    discType: item.discType,
                    discValue: item.discValue,
                    uom: item.uom,
                    sqft: item.sqft || 0,
                    sqm: item.sqm || 0,
                    afterDiscPricePiece: item.afterDiscPricePiece,
                    afterDiscPriceSqft: item.afterDiscPriceSqft,
                    price: item.unitPrice,
                    discount: item.discValue,
                    totalPrice: item.totalPrice,
                    roomType: item.roomType,
                    description: item.description,
                    requiredSqft: item.requiredSqft,
                     PricebookEntry: item.PricebookEntry
                };
            });

            console.log('Sending cart items to server:', JSON.stringify(cartItems));

            // Create cart and cart line items
            const cartId = await createCart({ 
                customerId: this.recordId,
                cartItems: cartItems,
                freightCharge: freightCharge || this.freightCharge || 0,
                loadingCharge: loadingCharge || this.loadingCharge || 0,
                unloadingCharge: unloadingCharge || this.unloadingCharge || 0,
                pbName :this.selectedPB,
                orderTotal : orderTotal || this.orderTotal || 0
            });

            // Show success message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Cart created successfully',
                    variant: 'success'
                })
            );

            // Close the modal
            this.showCartModal = false;

            // Clear the cart
            this.selectedProducts = [];
            localStorage.removeItem('selectedProducts');

            // Navigate to the created cart record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: cartId,
                    objectApiName: 'Cart__c',
                    actionName: 'view'
                }
            });

        } catch (error) {
            console.error('Error creating cart:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.message || 'Error creating cart. Please try again.',
                    variant: 'error'
                })
            );
        }
    }

    get cartCount() {
        return this.selectedProducts ? this.selectedProducts.length : 0;
    }

    // Handler for quantity changes in the cart modal
    handleCartQuantityChange(event) {
        const { itemId, quantity } = event.detail;
        console.log('Cart quantity change:', itemId, quantity);
        
        // Update the selectedProducts array with new quantity
        this.selectedProducts = this.selectedProducts.map(item => {
            // Check if this is the item to update (using compositeKey if available, fallback to id)
            const itemIdentifier = item.compositeKey || item.id;
            if (itemIdentifier === itemId) {
                // Recalculate total price
                let totalPrice;
                if (item.sqft > 0) {
                    // For sqft-based items, use afterDiscPriceSqft
                    totalPrice = (parseFloat(item.afterDiscPriceSqft) * item.sqft).toFixed(2);
                } else {
                    // For quantity-based items, use afterDiscPricePiece
                    totalPrice = (parseFloat(item.afterDiscPricePiece) * quantity).toFixed(2);
                }
                
                return {
                    ...item,
                    quantity: quantity,
                    totalPrice: totalPrice
                };
            }
            return item;
        });
        
        this.saveCartToLocalStorage();
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

        // Add debouncing to prevent too many updates
        this.searchTimeout = setTimeout(() => {
            const query = searchQuery.toLowerCase();
            
            console.log(JSON.stringify(this.products));
            // Filter products based on both search query and selected category
            this.searchResults = this.products
                .filter(product => {
                    const matchesSearch = (product.Name && product.Name.toLowerCase().includes(query)) || 
                        (product.Product_Code__c && product.Product_Code__c.toLowerCase().includes(query));
                    
                    // If a category is selected, filter by it
                    if (this.selectedCategory && this.selectedCategory !== '') {
                        return matchesSearch && product.Product_Category__c === this.selectedCategory;
                    }
                    
                    // If no category selected, return all matches
                    return matchesSearch;
                })
                .slice(0, 10); // Limit to 10 results for dropdown
 console.log('searchResults'+JSON.stringify(this.searchResults));
            this.showSearchDropdown = this.searchResults.length > 0;
        }, 300);
    }

    handleSearchResultClick(event) {
        const productId = event.currentTarget.dataset.productId;
        const selectedProduct = this.products.find(p => p.Id === productId);
        
        if (selectedProduct) {
            // Set the category of the selected product
            this.selectedCategory = selectedProduct.Product_Category__c;
            
            // Clear search query and close dropdown
            this.searchQuery = '';
            this.showSearchDropdown = false;
            
            // Update displayed products to show only the selected product
            this.displayedProducts = [selectedProduct];
        }
    }

    closeSearchDropdown() {
        this.showSearchDropdown = false;
    }

    // Add getter for opportunityId
    get opportunityId() {
        return this.recordId;
    }

    getStockStatusText(inStock) {
        return inStock ? 'In Stock' : 'Out of Stock';
    }

    handleRequiredSqftChange(event) {
        const productId = event.target.dataset.productId;
        const requiredSqft = parseFloat(event.target.value) || 0;
        
        // Update requiredSqft
        this.updateProduct(productId, 'requiredSqft', requiredSqft);
        
        // Calculate quantity based on Sqft/Piece
        const product = this.products.find(p => p.Id === productId);
        if (product && product.sqftPerPiece > 0 && requiredSqft > 0) {
            // Calculate quantity by dividing required sqft by sqft per piece and rounding up
            const quantity = Math.ceil(requiredSqft / product.sqftPerPiece);
            this.updateProduct(productId, 'quantity', quantity);
            
            // Calculate actual sqft based on the rounded up quantity
            const actualSqft = quantity * product.sqftPerPiece;
            this.updateProduct(productId, 'sqft', actualSqft);
            
            // Calculate sqm (1 sqft = 0.092903 sqm)
            const sqm = actualSqft * 0.092903;
            this.updateProduct(productId, 'sqm', sqm.toFixed(2));
        }
    }

    handleRoomTypeChange(event) {
        const productId = event.target.dataset.productId;
        const value = event.target.value;
        this.updateProduct(productId, 'roomType', value);
    }

    // Add new method for handling natural stone unit price changes
    handleNaturalStoneUnitPriceChange(event) {
        try {
            const productId = event.target.dataset.productId;
            const unitPrice = parseFloat(event.target.value) || 0;
            
            // Update only if value has changed
            const product = this.products.find(p => p.Id === productId);
            if (product && product.unitPrice !== unitPrice) {
                this.updateProduct(productId, 'unitPrice', unitPrice);
                this.calculateNaturalStonePrice(productId);
            }
        } catch (error) {
            console.error('Error in handleNaturalStoneUnitPriceChange:', error);
        }
    }

    // Add new method for handling natural stone required sqft changes
    handleNaturalStoneRequiredSqftChange(event) {
        try {
            const productId = event.target.dataset.productId;
            const requiredSqft = parseFloat(event.target.value) || 0;
            
            // Update only if value has changed
            const product = this.products.find(p => p.Id === productId);
            if (product && product.requiredSqft !== requiredSqft) {
                this.updateProduct(productId, 'requiredSqft', requiredSqft);
                this.calculateNaturalStonePrice(productId);
            }
        } catch (error) {
            console.error('Error in handleNaturalStoneRequiredSqftChange:', error);
        }
    }

    // Add new method for handling natural stone description changes
    handleNaturalStoneDescriptionChange(event) {
        try {
            const productId = event.target.dataset.productId;
            const description = event.target.value;
            
            // Update only if value has changed
            const product = this.products.find(p => p.Id === productId);
            if (product && product.description !== description) {
                this.updateProduct(productId, 'description', description);
            }
        } catch (error) {
            console.error('Error in handleNaturalStoneDescriptionChange:', error);
        }
    }

    // Add method to calculate natural stone price
    calculateNaturalStonePrice(productId) {
        try {
            const product = this.products.find(p => p.Id === productId);
            if (!product || !product.isNaturalStone) return;

            const unitPrice = parseFloat(product.unitPrice) || 0;
            const requiredSqft = parseFloat(product.requiredSqft) || 0;
            const discType = product.discType || 'Percentage';
            const discValue = parseFloat(product.discValue) || 0;
            
            let afterDiscPrice = unitPrice;
            let totalPrice = unitPrice * requiredSqft;
            
            if (discType === 'Percentage' && discValue > 0) {
                // For percentage discount
                const discountMultiplier = 1 - (discValue / 100);
                afterDiscPrice = unitPrice * discountMultiplier;
                totalPrice = afterDiscPrice * requiredSqft;
            } else if (discType === 'Amount' && discValue > 0) {
                // For amount, reduce from unit price
                afterDiscPrice = Math.max(unitPrice - discValue, 0);
                totalPrice = afterDiscPrice * requiredSqft;
            }
            
            // Update only if values have changed
            if (product.afterDiscPrice !== Number(afterDiscPrice).toFixed(2)) {
                this.updateProduct(productId, 'afterDiscPrice', Number(afterDiscPrice).toFixed(2));
            }
            if (product.totalPrice !== Number(totalPrice).toFixed(2)) {
                this.updateProduct(productId, 'totalPrice', Number(totalPrice).toFixed(2));
            }
        } catch (error) {
            console.error('Error in calculateNaturalStonePrice:', error);
        }
    }

    saveCartToLocalStorage() {
        localStorage.setItem('selectedProducts', JSON.stringify(this.selectedProducts));
    }
    
}