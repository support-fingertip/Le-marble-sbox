import { LightningElement, track, api,wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getProducts from '@salesforce/apex/NewQuoteController.getProducts';
import getPendingQuotes from '@salesforce/apex/NewQuoteController.getPendingQuotes';
import getPriceBookName from '@salesforce/apex/NewQuoteController.getPriceNames';
import getOpportunityItems from '@salesforce/apex/NewQuoteController.getOpportunityItems';
import getProductCategories from '@salesforce/apex/NewQuoteController.getProductCategories';
import getPBEntries from '@salesforce/apex/NewQuoteController.getPBEntries';
import createCart from '@salesforce/apex/NewQuoteController.createCart';
import checkLiveStock from '@salesforce/apex/NewQuoteController.checkLiveStock';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';


export default class NewQuoteFromOpp extends NavigationMixin(LightningElement) {
    
  //New_Quote_From_Opportunity
    @api recordId; 
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
openPreview=false;
    // Track the additional fields for cart summary
    @track freightCharge = 0;
    @track loadingCharge = 0;
    @track unloadingCharge = 0;
  @track orderTotal = 0;
@track useMRP = true; 
    get isCategoryDisabled() {
        return this.selectedPB;   // disabled when no Pricebook selected
    }
    
   /* get priceModeLabel() {
        return this.useMRP ? 'Using MRP' : 'Using MSP';
    }*/
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
    
    

    priceNames=[];//{ label: 'Select PriceBook', value: 'select' }
    categories = [ ]; //{ label: '------------', value: 'select' }


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
            //    this.selectedProducts = JSON.parse(savedCart);
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
                   { label: 'Select Category', value: '' },
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
            return category ? category.label : '-----------';
        }

        get showCartButton() {
            return this.filteredProducts.some(product => product.quantity > 0);
        }

        get showDiscountSection() {
         return this.selectedPB !== 'MSP';
        }
        get isCategoryDisabled() {
            return !this.selectedPB; // disable when selectedPB is false
        }
        handlePBSelect(event) {
           this.selectedCategory='';
                this.selectedProducts = [];
                localStorage.removeItem('selectedProducts');
            this.selectedPB = event.target.value;
            
            
        //    this.loadOLIFromOpportunity();

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
 //               this.updateProductUnitPrices();
            })
            .catch(error => {
                console.error(error);
            });
            
            // If there's an active search, refilter the results
            if (this.searchQuery) {
                this.handleSearchInput({ target: { value: this.searchQuery } });
            }
        }

        handleCategoryChange(event) {
            if(this.selectedCategory  !=event.target.value){
                this.products =[];
                this.selectedProducts=[];
            }
            this.selectedCategory = event.target.value;
        
            // Update all existing rows with the same category
            if (this.selectedCategory) {
                this.fetchProductsByCategory();
            }

            // Clear search results because category changed
            this.searchResults = [];
        }

        fetchProductsByCategory() {
                this.loadOLIFromOpportunity();

                    getProducts({ category: this.selectedCategory })
                    .then(result => {
                        console.log('Products received for category:', this.selectedCategory, result);
                        this.products = result;   // 🔥 Save directly
                    })
                    .catch(error => {
                        console.error('Error fetching products:', error);
                });
        }

        loadOLIFromOpportunity() {
        if (!this.recordId || !this.selectedPB) return;

        getOpportunityItems({ oppId: this.recordId, pricebookName: this.selectedPB, category: this.selectedCategory })
        .then(data => {
            if (data.length === 0) {
                   const cartItem1 = {
                id: '',
                 lineNo:1,
                compositeKey:'',
                name: '',
                code: '',
                category: this.selectedCategory,
                quantity: 0,
                unitPrice:0,
                afterDiscPricePiece:  0,
                totalPrice: 0,
                description: '',
                discType: '',
                discValue: 0,
                roomType: '',
                requiredSqft: 0,
                pricePerSqft: 0,
                afterDiscPriceSqft: 0,
                sqft: 0, sqm: 0,
                pricebookEntryId:'',
                 isNaturalStone: false,
                 isTile:false,
                showDropdown: false
            };

            this.selectedProducts = [...this.selectedProducts, cartItem1];


                console.log("No OLI found for this pricebook");
                return;
            }

            console.log("OLI Loaded:", data);

            data.forEach(item => {
                const compositeKey = `${item.Product2Id}_${item.Description || 'default'}`;

                const cartItem = {
                    id: item.Product2Id,
                    compositeKey:compositeKey,
                    name: item.Product2.Name,
                    code: item.Product2.Product_Code__c,
                    category: item.Product2.Product_Category__c,
                    quantity: item.Quantity,
                    unitPrice: item.UnitPrice,
                    afterDiscPricePiece: item.UnitPrice - (item.Discount || 0),
                    totalPrice: item.TotalPrice,
                    description: item.Description? item.Description: '',
                    discType: item.Discount > 0 ? 'Amount' : 'Percentage',
                    discValue: item.Discount || 0,
                    roomType: item.Area__c,
                    requiredSqft: 0,
                    pricePerSqft: 0,
                    afterDiscPriceSqft: 0,
                    sqft: 0, sqm: 0,
                    pricebookEntryId: item.PricebookEntryId,
                     isNaturalStone: item.Product2.Product_Category__c === 'NATURAL STONE',
                     isTile:item.Product2.Product_Category__c === 'TILE',
                    showDropdown: false
                };

                this.selectedProducts = [...this.selectedProducts, cartItem];
            });

            this.saveCartToLocalStorage();
        })
        .catch(error => console.error("Failed to Fetch OLI:", error));
        }
        handlePriceToggle(event) {
            this.useMRP = event.target.checked;
        }


      /*  updateProductUnitPrices() {
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
            }*/


        handleCategorySelect(event) {
            const selectedValue = event.target.value;
            const rowIndex = Number(event.target.dataset.index);

            // Remove the selected row
            let rows = [...this.selectedProducts];
            rows.splice(rowIndex, 1);

            // Create new blank row
            const newRow = {
                id: '',
                compositeKey:'',
                lineNo:rowIndex+1,
                name: '',
                code: '',
                category: selectedValue,   
                quantity: 0,
                unitPrice: 0,
                afterDiscPricePiece: 0,
                totalPrice: 0,
                description: '',
                discType: '',
                discValue: 0,
                roomType: '',
                requiredSqft: 0,
                pricePerSqft: 0,
                afterDiscPriceSqft: 0,
                sqft: 0,
                sqm: 0,
                pricebookEntryId: '',
                isNaturalStone: false,
                isTile: false,
                showDropdown: false
            };

            // Insert new row at same position
            rows.splice(rowIndex, 0, newRow);

            // Update UI
            this.selectedProducts = rows;

            

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
            const idx = event.target.dataset.index;
            const quantity = parseInt(event.target.value) || 0;
            this.updateProduct(productId, 'quantity', quantity,idx);

            // Find the product and update sqft/requiredSqft/sqm if it's a tile
            const product = this.selectedProducts[idx];
            if (product && product.isTile && !isNaN(product.sqftPerPiece) && product.sqftPerPiece > 0) {
                const sqft = Number((quantity * product.sqftPerPiece).toFixed(3));
                this.updateProduct(productId, 'sqft', sqft,idx);
                this.updateProduct(productId, 'requiredSqft', sqft,idx);
                this.updateProduct(productId, 'sqm', (sqft * 0.092903).toFixed(2),idx);
            }
            this.recalculateOrderTotal();
        }

        handleDiscTypeChange(event) {
            try {
            const productId = event.target.dataset.productId;
            const discType = event.target.value;
              const idx = event.target.dataset.index;
              
              
                // Update only if value has changed
                const product = this.selectedProducts[idx];
                if (product && product.discType !== discType) {
            this.updateProduct(productId, 'discType', discType,idx);
                    
                    if (product.isNaturalStone) {
                        this.calculateNaturalStonePrice(productId,idx);
                    } else {
                        this.calculatePrices(idx);
                    }
                }
            } catch (error) {
                console.error('Error in handleDiscTypeChange:', error);
            }
        }

        handleDiscValueChange(event) {
            try {
                 const idx = event.target.dataset.index;
            const productId = event.target.dataset.productId;
            const discValue = parseFloat(event.target.value) || 0;
                
                // Update only if value has changed
                const product = this.selectedProducts[idx];
                if (product && product.discValue !== discValue) {
            this.updateProduct(productId, 'discValue', discValue,idx);
                    
                    if (product.isNaturalStone) {
                        this.calculateNaturalStonePrice(productId,idx);
                    } else {
                        this.calculatePrices(idx);
                    }
                }
            } catch (error) {
                console.error('Error in handleDiscValueChange:', error);
            }
        }

        handleSqftChange(event) {
            const productId = event.target.dataset.productId;
            const sqft = Number((parseFloat(event.target.value) || 0).toFixed(3));
             const idx = event.target.dataset.index;
            // Update sqft
            this.updateProduct(productId, 'sqft', sqft,idx);
            
            // Calculate and update sqm (1 sqft = 0.092903 sqm)
            const sqm = sqft * 0.092903;
            this.updateProduct(productId, 'sqm', sqm.toFixed(2),idx);

            // Calculate quantity based on Sqft/Piece
          const product = this.selectedProducts[idx];
            
            if (product && !isNaN(product.sqftPerPiece) && product.sqftPerPiece > 0 && sqft > 0) {
                // Calculate quantity by dividing total sqft by sqft per piece
                const quantity = Math.ceil(sqft / product.sqftPerPiece);
                this.updateProduct(productId, 'quantity', quantity,idx);

                // Calculate final sqft based on the rounded up quantity
                const finalSqft = Number((quantity * product.sqftPerPiece).toFixed(3));
                this.updateProduct(productId, 'requiredSqft', finalSqft,idx);
            }
        }

        updateProduct(productId, field, value,idx) {
            const productIndex = idx;
            
            if (productIndex !== -1) {
                this.selectedProducts [productIndex][field] = value;
                 const product = this.selectedProducts[productIndex];
                const newKey = `${product.id || ''}_${product.roomType || 'default'}_${product.description || 'default'}`;
                product.compositeKey = newKey;

        
                this.calculatePrices(productIndex);
                this.selectedProducts  = [...this.selectedProducts ]; // Trigger reactivity
            }
        }

        calculatePrices(productIndex) {
            const product = this.selectedProducts [productIndex];
     //    alert(JSON.stringify(product));   
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
                this.selectedProducts  = [...this.selectedProducts];
                return;
            }

            // For TILES
            if (product.isTile) {
                const unitPrice = parseFloat(product.unitPrice) || 0;
                const taxPercent = parseFloat(product.Tax) || 0;
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

                this.selectedProducts  = [...this.selectedProducts];
                return;
            }

            // For OTHER CATEGORIES
            const unitPrice = parseFloat(product.unitPrice) || 0;
            const taxPercent = parseFloat(product.Tax) || 0;
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
            this.selectedProducts  = [...this.selectedProducts];
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

        
        handleImageError(event) {
            event.target.src = 'https://www.levarusglobal.com/wp-content/uploads/2021/06/no-product-image.jpg';
        }

        handleCheckStock(event) {
            const index = event.target.dataset.index;
            const item = this.selectedProducts[index];

            if (!item.code) {
                return;
            }
            checkLiveStock({ itemcode: item.code })
                .then(result => {
                    const stockQty = Number(result);

                    const updatedItem = {
                        ...item,
                        stockChecked: true,
                        inStock: stockQty > 0,
                        stockCount: stockQty
                    };

                    this.updateRow(index, updatedItem);
                })
                .catch(error => {
                    console.error('Stock check failed', error);

                    const updatedItem = {
                        ...item,
                        stockChecked: true,
                        inStock: false,
                        stockCount: 0
                    };

                    this.updateRow(index, updatedItem);
                });
        }
  /* handleAddToCart(event) {
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
                     PricebookEntry: product.PricebookEntry,
                     showDropdown: false
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
                     PricebookEntry: product.PricebookEntry,
                     showDropdown: false
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
        } 
        else {
            // Show error toast if neither quantity nor sqft is provided
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please enter either Quantity or Sqft before adding to Quote',
                    variant: 'error'
                })
            );
        }
        this.saveCartToLocalStorage();
    }
*/

    handlePreview() {

        
        if (!this.selectedProducts || this.selectedProducts.length === 0) {
            this.showError('No products added to preview');
        return;
    }

//duplicate
   const validRows = this.selectedProducts
    .map((item, index) => ({ item, index }))
    .filter(({ item }) =>
        item.quantity > 0 ||
        item.sqft > 0 ||
        (item.isNaturalStone && item.requiredSqft > 0)
    );
    if (validRows.length > 1) {

    // 2. Create an array of keys only for valid rows
    const keys = validRows.map(r => r.item.compositeKey);

    // 3. Detect duplicates
    const duplicates = [];
    keys.forEach((key, i) => {
        if (keys.indexOf(key) !== i) {
            duplicates.push(validRows[i].index + 1); // convert to 1-based
        }
    });
    if (duplicates.length > 0) {
        this.showError(
            `Duplicate product entries found in rows: ${duplicates.join(', ')}`
        );
        return;
    }
} 
    
    // VALIDATION LOOP
    for (let item of this.selectedProducts) {
        if (!item.roomType || item.roomType.trim() === '') {
            this.showError(`Please enter Area/Room Type for product: ${item.name}`);
            return;
        }

        if (item.isNaturalStone && (!item.requiredSqft || item.requiredSqft <= 0)) {
            this.showError(`Please enter Required Sqft for natural stone: ${item.name}`);
            return;
        }

        if (item.isTile && (!item.requiredSqft || item.requiredSqft <= 0)) {
            this.showError(`Please enter Required Sqft for tile: ${item.name}`);
            return;
        }

        if (!item.isNaturalStone && !item.isTile) {
            if (!item.quantity || item.quantity <= 0) {
                this.showError(`Please enter Quantity for product: ${item.name}`);
                return;
            }
        }

        if (!item.pricebookEntryId || item.pricebookEntryId === '') {
            this.showError(`Pricebook Entry not available for: ${item.name}`);
            return;
        }

        if (!item.totalPrice || Number(item.totalPrice) <= 0) {
            this.showError(`Invalid total price for: ${item.name}`);
            return;
        }
    }

    // 🔥 BUILD PREVIEW DISPLAY FIELDS FOR ALL ITEMS
    this.selectedProducts = this.selectedProducts.map(item => {
        
        let unitPriceDisplay = 0;
        let afterDiscDisplay = 0;
        let lineTotalDisplay = 0;

        if (item.isNaturalStone) {
            unitPriceDisplay = item.unitPrice || 0;

            if (item.discType === 'Percentage') {
                afterDiscDisplay = item.afterDiscPrice || 0;
                lineTotalDisplay = afterDiscDisplay * (item.requiredSqft || 0);

            } else if (item.discType === 'Amount') {
                afterDiscDisplay = Math.max(item.unitPrice - item.discValue, 0);
                lineTotalDisplay = afterDiscDisplay * (item.requiredSqft || 0);

            } else {
                afterDiscDisplay = item.unitPrice || 0;
                lineTotalDisplay = item.unitPrice * (item.requiredSqft || 0);
            }
        }
        else if (item.isTile) {
            unitPriceDisplay = item.unitPriceAfterTax || 0;
            afterDiscDisplay = item.afterDiscPriceSqft || 0;
            lineTotalDisplay = afterDiscDisplay * (item.requiredSqft || 0);
        }
        else {
            unitPriceDisplay = item.unitPriceAfterTax || 0;
            afterDiscDisplay = item.afterDiscPricePiece || 0;
            lineTotalDisplay = afterDiscDisplay * (item.quantity || 0);
        }
this.recalculateOrderTotal();
        return {
            ...item,
            discountSymbol: item.discType === 'Percentage' ? '%' : '\u20b9',
            unitPriceDisplay,
            afterDiscDisplay,
            lineTotalDisplay: Number(lineTotalDisplay).toFixed(2)
        };
    });

    // OPEN PREVIEW
    this.openPreview = true;
}



    handleClosePreview() {
        this.openPreview = false;
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
        this.freightCharge = parseFloat(event.target.value) || 0;
        this.recalculateOrderTotal();
    }

    handleLoadingChargeChange(event) {
        this.loadingCharge = parseFloat(event.target.value) || 0;
        this.recalculateOrderTotal();
    }

    handleUnloadingChargeChange(event) {
        this.unloadingCharge = parseFloat(event.target.value) || 0;
        this.recalculateOrderTotal();
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
 /*           this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Creating Cart',
                    message: 'Please wait while we create your cart...',
                    variant: 'info'
                })
            );*/

            // Get cart summary values from the modal
       //     const { freightCharge, loadingCharge, unloadingCharge,orderTotal } = event.detail.summary || {};

            // Prepare cart items with only the necessary data to minimize payload size
            const cartItems = this.selectedProducts.map(item => {
                return {
                    id: item.id,
                    compositeKey:item.compositeKey,
                    category: item.category,
                    quantity: item.quantity,
                    unitPriceAfterTax: item.unitPriceAfterTax, // after-tax value for tiles/other products
                    pricePerSqft: item.pricePerSqft,           // after-tax per sqft for tiles
                    unitPrice: item.unitPrice,  
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
                    pricebookEntryId: item.pricebookEntryId,
                     showDropdown: false
                };
            });

            console.log('Sending Quote items to server:', JSON.stringify(cartItems));

            // Create cart and cart line items
            const cartId = await createCart({ 
                customerId: this.recordId,
                cartItems: cartItems,
                freightCharge: this.freightCharge || 0,
                loadingCharge: this.loadingCharge || 0,
                unloadingCharge: this.unloadingCharge || 0,
                pbName :this.selectedPB,
                orderTotal : this.orderTotal || 0
            });

            // Show success message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Quote created successfully',
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
            console.error('Error creating Quote:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.message || 'Error creating Quote. Please try again.',
                    variant: 'error'
                })
            );
            this.openPreview=false;
        }
    }

    get cartCount() {
        return this.selectedProducts ? this.selectedProducts.length : 0;
    }

    // Handler for quantity changes in the cart modal
   /*  handleCartQuantityChange(event) {
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
alert('hi');
        const searchQuery = event.target.value;
        this.searchQuery = searchQuery;
        
        if (!searchQuery) {
            this.showSearchDropdown = false;
            this.searchResults = [];
            return;
        }
       //     console.log('this.products>>>'+JSON.stringify(this.products));

        // Add debouncing to prevent too many updates
        this.searchTimeout = setTimeout(() => {
            const query = searchQuery.toLowerCase();
            
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
            this.showSearchDropdown = this.searchResults.length > 0;
        }, 300);
    }

    handleSearchResultClick(event) {
        alert(1);
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

        alert(this.displayedProducts);
    }
*/



        handleSearchFocus(event) {
            // optional: set activeRowIndex when the input gets focus
            const idx = event.currentTarget.dataset.index;
            this.activeRowIndex = typeof idx !== 'undefined' ? Number(idx) : null;
        }

        handleSearchInput(event) {
            const index = event.target.dataset.index;
            const value = event.target.value;

            this.activeRowIndex = Number(index);

            // Update the text being typed
            let updated = [...this.selectedProducts];
            updated[index].name = value;   // << KEY FIX
            this.selectedProducts = updated;

            // Now process search
            if (!value || value.length < 1) {
                this.searchResults = [];
                this.showSearchDropdown = false;
                return;
            }
const rowCategory = this.selectedProducts[index].category;
         /*   this.searchResults = this.products.filter(p =>
                (p.Name || '').toLowerCase().includes(value.toLowerCase()) ||
                (p.Product_Code__c || '').toLowerCase().includes(value.toLowerCase())
            );

            this.showSearchDropdown = this.searchResults.length > 0;
            this.selectedProducts = this.selectedProducts.map((row, i) => ({
                ...row,
                showDropdown: i == index
            }));*/

            this.searchResults = this.products.filter(p => {
                const matchesSearch =
                    (p.Name || '').toLowerCase().includes(value.toLowerCase()) ||
                    (p.Product_Code__c || '').toLowerCase().includes(value.toLowerCase());
                if (rowCategory && rowCategory !== '' && rowCategory !== 'select') {
                    return matchesSearch && p.Product_Category__c === rowCategory;
                }

                return matchesSearch; // no category filter applied
            });
            this.showSearchDropdown = this.searchResults.length > 0;

            this.selectedProducts = this.selectedProducts.map((row, i) => ({
                ...row,
                showDropdown: i == index
            }));
}





handleSearchResultClick(event) {
    // find clicked element (works even if inner child was clicked)
    const el = event.target.closest('[data-product-id]');
    if (!el) return;

    const productId = el.dataset.productId;
    // find the product in the same array you rendered
    const selectedProduct = (this.searchResults || []).find(p => String(p.Id) === String(productId))
                         || (this.products || []).find(p => String(p.Id) === String(productId));

    if (!selectedProduct) {
      console.warn('product not found for id', productId);
      return;
    }

    const unitPrice = this.pbEntryMap?.get(selectedProduct.Id) || 0;
    const pricebookEntryId = this.pbEntryIdMap?.get(selectedProduct.Id) || '';

 //alert(JSON.stringify(pricebookEntryId));
    // Ensure we have a valid activeRowIndex
    const row = (typeof this.activeRowIndex === 'number' && this.selectedProducts[this.activeRowIndex])
              ? this.selectedProducts[this.activeRowIndex]
              : null;

    if (row) {
      // update only the specific row (reactive)
      // Important: modify a copy so LWC tracks the change
        const updated = JSON.parse(JSON.stringify(this.selectedProducts));
        updated[this.activeRowIndex].id = selectedProduct.Id;
        updated[this.activeRowIndex].name = selectedProduct.Name;
        updated[this.activeRowIndex].code = selectedProduct.Product_Code__c;
        updated[this.activeRowIndex].category = selectedProduct.Product_Category__c || '';
        updated[this.activeRowIndex].isNaturalStone= selectedProduct.Product_Category__c === 'NATURAL STONE';
        updated[this.activeRowIndex].quantity= selectedProduct.Product_Category__c === 'NATURAL STONE' ? 1:0;

        updated[this.activeRowIndex].isTile= selectedProduct.Product_Category__c === 'TILE';
        
        updated[this.activeRowIndex].showDropdown = false;

        updated[this.activeRowIndex].unitPrice = unitPrice;
        updated[this.activeRowIndex].priceSqft = unitPrice;
        updated[this.activeRowIndex].pricebookEntryId = pricebookEntryId;
        updated[this.activeRowIndex].sqftPerPiece=selectedProduct.Sqft_Piece__c;
        updated[this.activeRowIndex].Tax=selectedProduct.Tax__c;
        updated[this.activeRowIndex].totalPrice =
            (updated[this.activeRowIndex].quantity || 0) * unitPrice;
        updated[this.activeRowIndex].isRegularProduct = (!updated[this.activeRowIndex].isTile && !updated[this.activeRowIndex].isNaturalStone);

       console.log(JSON.stringify(updated));
      // set any other fields like price etc.
      this.selectedProducts = updated;
    } else {
          this.selectedProducts = [
            {
                ...selectedProduct,
                unitPrice: unitPrice,
                priceSqft: unitPrice,
                pricebookEntryId: pricebookEntryId,
                totalPrice: (selectedProduct.quantity || 0) * unitPrice
            }
        ];
      // fallback — update displayedProducts or single selection
  //    this.selectedProducts = [ selectedProduct ];
    }

    // Clear search UI
    this.searchQuery = '';
    this.searchResults = [];
    this.showSearchDropdown = false;
    this.activeRowIndex = null;
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
         const idx = event.target.dataset.index;
        
        // Update requiredSqft
        this.updateProduct(productId, 'requiredSqft', requiredSqft,idx);
        
        // Calculate quantity based on Sqft/Piece
       const product = this.selectedProducts[idx];
        if (product && product.sqftPerPiece > 0 && requiredSqft > 0) {
            // Calculate quantity by dividing required sqft by sqft per piece and rounding up
            const quantity = Math.ceil(requiredSqft / product.sqftPerPiece);
            this.updateProduct(productId, 'quantity', quantity);
            
            // Calculate actual sqft based on the rounded up quantity
            const actualSqft = quantity * product.sqftPerPiece;
            this.updateProduct(productId, 'sqft', actualSqft);
            
            // Calculate sqm (1 sqft = 0.092903 sqm)
            const sqm = actualSqft * 0.092903;
            this.updateProduct(productId, 'sqm', sqm.toFixed(2),idx);
        }
    }

    handleRoomTypeChange(event) {
        const productId = event.target.dataset.productId;
        const value = event.target.value;
        const idx = event.target.dataset.index;

        this.updateProduct(productId, 'roomType', value,idx);
    }

    // Add new method for handling natural stone unit price changes
    handleNaturalStoneUnitPriceChange(event) {
        try {
            const productId = event.target.dataset.productId;
            const unitPrice = parseFloat(event.target.value) || 0;
             const idx = event.target.dataset.index;
            
            // Update only if value has changed
            const product = this.selectedProducts[idx];
            if (product && product.unitPrice !== unitPrice) {
                this.updateProduct(productId, 'unitPrice', unitPrice,idx);
                this.calculateNaturalStonePrice(productId,idx);
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
             const idx = event.target.dataset.index;
            // Update only if value has changed
            const product = this.selectedProducts[idx];
            if (product && product.requiredSqft !== requiredSqft) {
                this.updateProduct(productId, 'requiredSqft', requiredSqft,idx);
                this.calculateNaturalStonePrice(productId,idx);
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
            const idx = event.target.dataset.index;
            // Update only if value has changed
            const product = this.selectedProducts[idx];
            if (product && product.description !== description) {
                this.updateProduct(productId, 'description', description,idx);
            }
        } catch (error) {
            console.error('Error in handleNaturalStoneDescriptionChange:', error);
        }
    }

    // Add method to calculate natural stone price
    calculateNaturalStonePrice(productId,idx) {
        try {
            const product = this.selectedProducts[idx];
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
                this.updateProduct(productId, 'afterDiscPrice', Number(afterDiscPrice).toFixed(2),idx);
            }
            if (product.totalPrice !== Number(totalPrice).toFixed(2)) {
                this.updateProduct(productId, 'totalPrice', Number(totalPrice).toFixed(2),idx);
            }
            this.recalculateOrderTotal();
        } catch (error) {
            console.error('Error in calculateNaturalStonePrice:', error);
        }
    }

    saveCartToLocalStorage() {
        localStorage.setItem('selectedProducts', JSON.stringify(this.selectedProducts));
    }
          



      addRow(event){
        const index = event.target.dataset.index;
        this.addItemRecord(index);
    }


        removeRow(event) {
        let index = event.currentTarget.dataset.index;
        let items = [...this.selectedProducts];
     /*   if (items[index].Id) {
            this.DeleteItemLine = [...(this.DeleteExpLine || []), items[index].Id];
        }*/
        items.splice(index, 1);
        
        // Recalculate index values
    /*    items = items.map((item, i) => ({
            ...item,
            indexvalue: i + 1
        }));*/
        this.selectedProducts = items;

        if (items.length < 1) {
            this.addItemRecord(0);
        }
         this.updateLineNumbers();
          this.recalculateOrderTotal();
        //this.getGrandTotal();
    }


        addItemRecord(index) {
        let items = [...this.selectedProducts];
  //      if (index === -1) {

           const newItem ={
            lineNo:index+1,
                    id: '',
                    compositeKey:'',
                    name: '',
                    code: '',
                    category: '',
                    quantity: 0,
                    unitPrice:0,
                    afterDiscPricePiece:  0,
                    totalPrice: 0,
                    description: '',
                    discType: '',
                    discValue: 0,
                    roomType: '',
                    requiredSqft: 0,
                    pricePerSqft: 0,
                    afterDiscPriceSqft: 0,
                    sqft: 0, sqm: 0,
                    pricebookEntryId:'',
                     isNaturalStone: false,
                      isTile: false,
                    showDropdown: false
            };

            console.log('length>>'+items.length+'>>'+index );
        if (items.length > 1) {
            const insertPos = Number(index) + 1;
             console.log('insertPos>>'+insertPos );
                items.splice(insertPos, 0, newItem);
            } else {
                items.push(newItem);
            }
            console.log('items>>'+items );
                this.selectedProducts = items;


            this.updateLineNumbers();

            }

            updateLineNumbers() {
                this.selectedProducts = this.selectedProducts.map((item, index) => {
                    return { 
                        ...item, 
                        lineNo: index + 1 
                    };
                });
            }
        closeComponent() {

            // Navigate back to the Quote record
            if (this.recordId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        objectApiName: 'Opportunity',   
                        actionName: 'view'
                    }
                });
            }
        }

        showError(msg) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: msg,
                variant: 'error'
            })
        );
        }

        closePreview() {
                    this.showPreview = false;
                }
        recalculateOrderTotal() {
            const subtotal = this.selectedProducts?.reduce((sum, item) => {
                return sum + (parseFloat(item.totalPrice) || 0);
            }, 0) || 0;
            this.orderTotal = (
                subtotal +
                (parseFloat(this.freightCharge) || 0) +
                (parseFloat(this.loadingCharge) || 0) +
                (parseFloat(this.unloadingCharge) || 0)
            ).toFixed(2);
        }
        get subtotal() {
            return this.selectedProducts.reduce((sum, item) => {
                return sum + (parseFloat(item.totalPrice) || 0);
            }, 0).toFixed(2);
        }
       
        buildCategoryList(selectedValue) {
    return this.categories.map(cat => ({
        ...cat,
        isSelected: cat.value === selectedValue
    }));
}
        get afterDiscPriceLabel() {
            console.log('this.selectedCategory>>>>>>'+this.selectedCategory);
            return this.selectedCategory === 'TILE'
                ? 'After Disc / Sqft'
                : 'After Disc';
        }
        handleDragStart(event) {
            this.draggedIndex = Number(event.currentTarget.dataset.index);
            event.currentTarget.classList.add('dragging');
        }

        // 🔹 Allow drop
        handleDragOver(event) {
            event.preventDefault();
        }

        // 🔹 Drop & rearrange
        handleDrop(event) {
            event.preventDefault();

            const droppedIndex = Number(event.currentTarget.dataset.index);

            if (this.draggedIndex === droppedIndex) {
                return;
            }

            const items = [...this.selectedProducts];
            const draggedItem = items.splice(this.draggedIndex, 1)[0];
            items.splice(droppedIndex, 0, draggedItem);

            this.selectedProducts = items;
            this.draggedIndex = null;
        }
        

    }