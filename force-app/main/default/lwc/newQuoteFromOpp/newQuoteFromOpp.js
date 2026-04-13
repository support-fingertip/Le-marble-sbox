import { LightningElement, track, api,wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getProducts from '@salesforce/apex/NewQuoteController.getProducts';
import getPendingQuotes from '@salesforce/apex/NewQuoteController.getPendingQuotes';
import getPriceBookName from '@salesforce/apex/NewQuoteController.getPriceNames';
import getOpportunityItems from '@salesforce/apex/NewQuoteController.getOpportunityItems';
import getProductCategories from '@salesforce/apex/NewQuoteController.getProductCategories';
//import getPBEntries from '@salesforce/apex/NewQuoteController.getPBEntries';
import createCart from '@salesforce/apex/NewQuoteController.createCart';
import checkLiveStock from '@salesforce/apex/NewQuoteController.checkLiveStock';
import getAreaPicklistValues from '@salesforce/apex/NewQuoteController.getAreaPicklistValues';

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
     @track isConfirmed = false;
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
    @track roundOff=0;
  @track orderTotal = 0;
@track useMRP = true; 
    get isCategoryDisabled() {
        return !this.selectedPB || this.selectedPB === 'select';  // disabled when no Pricebook selected
    }

    get selectedPBLabel() {
        const entry = this.priceNames.find(pb => pb.value === this.selectedPB);
        return entry ? entry.label : this.selectedPB;
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

    @track areaOptions = [];

@wire(getAreaPicklistValues)
wiredAreaPicklist({ data, error }) {
    if (data) {
        this.areaOptions = data.map(v => ({
    label: v.label,
    value: v.value
}));
    } else if (error) {
        console.error('❌ Error loading Area picklist:', error);
    }
}



    
    

    priceNames=[];//{ label: 'Select PriceBook', value: 'select' }
    categories = [ ]; //{ label: '------------', value: 'select' }


    connectedCallback() {
        this.initializeRecordId();

        if(this.recordId){
            this.checkPendingQuotes();   // 👈 trigger on component load
        }

        this.selectedProducts = [];
        localStorage.removeItem('selectedProducts');

        // If pricebook was already auto-selected by wire but recordId wasn't ready,
        // trigger the load now that recordId is available
        this.tryLoadDefaultPricebook();

        // Load cart from localStorage if available
     /*   const savedCart = localStorage.getItem('selectedProducts');
        if (savedCart) {
            try {
            //    this.selectedProducts = JSON.parse(savedCart);
            } catch (e) {
                this.selectedProducts = [];
            }
        }*/

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
    
                //  Redirect automatically to Quote record page
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
                   // { label: 'Select Pricebook', value: 'select' },
                    ...data.map(priceName => ({
                        
                         label:
                    priceName === 'Standard Price Book'
                        ? 'RETAIL/MRP'
                        : priceName,
                        value: priceName
                    }))
                ];

                // Auto-select RETAIL/MRP (Standard Price Book) as default
                const retailEntry = this.priceNames.find(
                    pb => pb.label === 'RETAIL/MRP'
                );
                if (retailEntry && (!this.selectedPB || this.selectedPB === 'select')) {
                    this.selectedPB = retailEntry.value;
                }
                // Try loading — will only proceed if recordId is also ready
                this.tryLoadDefaultPricebook();
            } else if (error) {
                this.error = error;
                console.error('Error fetching priceNames:', error);
            }
        }

        _defaultPBLoaded = false;

        tryLoadDefaultPricebook() {
            // Only proceed when both recordId and selectedPB are available, and not already loaded
            if (!this.recordId || !this.selectedPB || this.selectedPB === 'select' || this._defaultPBLoaded) {
                return;
            }
            this._defaultPBLoaded = true;

            console.log('Loading default pricebook data for:', this.selectedPB);
            this.loadOLIFromOpportunity();
          /*  getPBEntries({ pbName: this.selectedPB })
                .then(result => {
                    console.log('Default Pricebook Entries:', result);
                    this.pbEntryMap = new Map();
                    this.pbEntryIdMap = new Map();
                    result.forEach(entry => {
                        this.pbEntryMap.set(entry.Product2Id, entry.UnitPrice);
                        this.pbEntryIdMap.set(entry.Product2Id, entry.Id);
                    });
                })
                .catch(error => {
                    console.error('Error loading default PB entries:', error);
                });*/
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

        get showMRPSection() {
         return this.selectedPB !== 'RETAIL/MRP';
        }
       // get isCategoryDisabled() {
       //     return !this.selectedPB; // disable when selectedPB is false
       // }
        handlePBSelect(event) {
        //   this.selectedCategory='';
         //       this.selectedProducts = [];
                localStorage.removeItem('selectedProducts');
            
            if(this.selectedPB  !=event.target.value){
                this.products =[];
                this.selectedProducts=[];
            }
            
           this.selectedPB = event.target.value;
  
           this.loadOLIFromOpportunity();

            // Clear search results when category changes
            this.searchResults = [];
            this.showSearchDropdown = false;
          /*  getPBEntries({ pbName: this.selectedPB })
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
            });*/
            
            // If there's an active search, refilter the results
            if (this.searchQuery) {
                this.handleSearchInput({ target: { value: this.searchQuery } });
            }
        }

     /*  handleCategoryChange(event) {
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

                    getProducts({ category: this.selectedCategory,pricebookName: this.selectedPB })
                    .then(result => {
                        console.log('Products received for category:', this.selectedCategory, result);
                        this.products = result;   // 🔥 Save directly
                    })
                    .catch(error => {
                        console.error('Error fetching products:', error);
                });
        }
*/
        loadOLIFromOpportunity() {
        if (!this.recordId || !this.selectedPB) return;

        getOpportunityItems({ oppId: this.recordId, pricebookName: this.selectedPB })
        .then(data => {
            if (data.length === 0) {
                   const cartItem1 = {
                id: '',
                 lineNo:1,
                compositeKey: `${Date.now()}_${Math.random()}`,
                name: '',
                code: '',
                category: '',
                quantity: 0,
                unitPrice:0,
                afterDiscPricePiece:  0,
                afterDiscPricePieceWithoutTax:  0,
                 afterDiscPriceSqftWithoutTax:  0,
                  afterDiscPrice: 0,
                afterDiscPriceWithoutTax: 0,
                totalPrice: 0,
                description: '',
                discType: 'Amount',
                discValue: 0,
                roomType: '',
                 areaDesc: '',
                requiredSqft: 0,
                pricePerSqft: 0,
                afterDiscPriceSqft: 0,
                sqft: 0, sqm: 0,
                pricebookEntryId:'',
                 isNaturalStone: false,
                 isTile:false,
                showDropdown: false,
                isActive: true,
                 rowClass: 'item-card active'
            };

            this.selectedProducts = [...this.selectedProducts, cartItem1];


                console.log("No OLI found for this pricebook");
                return;
            }

            console.log("OLI Loaded:", data);
var i=0;
            data.forEach(item => {
                const compositeKey = `${item.Product2Id}_${item.Area__c || 'default'}`;
                i=i+1;
                const cartItem = {
                       lineNo:i,
                    id: item.Product2Id,
                   
                    name: item.Product2.Name,
                    code: item.Product2.Product_Code__c,
                    category: item.Product2.Product_Category__c,
                    quantity: item.Quantity,
                    unitPrice: item.UnitPrice,
                    msp: item.msp,
                    afterDiscPricePiece: item.UnitPrice,
                    afterDiscPricePieceWithoutTax:  0,
                 afterDiscPriceSqftWithoutTax:  0,
                    afterDiscPrice: 0,
                    afterDiscPriceWithoutTax: 0,
                    totalPrice: item.TotalPrice,
                    description: item.Description? item.Description: '',
                    discType: item.Disc_Type__c,
                    discValue: item.Dis_Value__c || 0,
                    roomType: item.Area__c,
                        areaDesc: item.Room_Type__c,
                    requiredSqft: item.Sqft__c,
                    pricePerSqft: 0,
                    Tax:item.Product2.Tax__c || 0,
                    afterDiscPriceSqft: 0,
                    sqft: item.Sqft__c, sqm: 0,
                    sqftPerPiece:item.Product2.Sqft_Piece__c || 0,
                    pricebookEntryId: item.PricebookEntryId,
                        isNaturalStone: item.Product2.Product_Category__c === 'N.STONE',
                     isTile:item.Product2.Product_Category__c === 'TILE',
                    showDropdown: false,
                isActive: false,
                rowClass: 'item-card'
                    
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




        handleRowClick(event) {
            const clickedIndex = Number(event.currentTarget.dataset.index);

            this.selectedProducts = this.selectedProducts.map((item, index) => {
                const isActive = index === clickedIndex;

                return {
                    ...item,
                    isActive,
                    rowClass: isActive ? 'item-card active' : 'item-card'
                };
                });
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
            }

        handleCategorySelect(event) {
            const selectedValue = event.target.value;
            const rowIndex = Number(event.target.dataset.index);

            // Remove the selected row
            let rows = [...this.selectedProducts];
            rows.splice(rowIndex, 1);

            // Create new blank row
           const newRow = {
   compositeKey: `${Date.now()}_${Math.random()}`,
                id: '',
             
                lineNo:rowIndex+1,
                name: '',
                code: '',
                category: selectedValue,   
                quantity: 0,
                unitPrice: 0,
                msp: 0,
                afterDiscPricePiece: 0,
                totalPrice: 0,
                description: '',
                discType: 'Amount',
                discValue: 0,
                roomType: '', 
                areaDesc: '',
                requiredSqft: 0,
                pricePerSqft: 0,
                afterDiscPriceSqft: 0,
                sqft: 0,
                sqm: 0,
                pricebookEntryId: '',
                isNaturalStone: false,
                isTile: false,
                showDropdown: false,
                isActive: false,
                rowClass: 'item-card'
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
        }*/

        handleRowCategoryChange(event) {
            const index = Number(event.target.dataset.index);
            const value = event.detail.value;

            let rows = [...this.selectedProducts];

            rows[index] = {
                ...rows[index],
                category: value,
                id: '',
                name: '',
                code: '',
                quantity: 0,
                unitPrice: 0,
                totalPrice: 0,
                showDropdown: false
            };

            this.selectedProducts = rows;
            this.searchResults = [];
         }


        handleQuantityChange(event) {
            const idx = event.target.dataset.index;
            const quantity = parseInt(event.target.value) || 0;

            // ONLY update quantity → no re-render storm
            this.selectedProducts[idx].quantity = quantity;
        }

        handleQuantityBlur(event) {
            const productId = event.target.dataset.productId;
            const idx = event.target.dataset.index;
            const quantity = parseInt(event.target.value) || 0;
             this.selectedProducts[idx].quantity = quantity;
        console.log('productId'+productId); 
        console.log('idx'+idx); 
        console.log('quantity'+quantity); 
        console.log('this.selectedProducts[idx].quantity ' +this.selectedProducts[idx].quantity); 

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

    updateProduct(productId, field, value, idx) {
        const productIndex = idx;

        if (productIndex !== -1) {
            this.selectedProducts[productIndex][field] = value;

            const product = this.selectedProducts[productIndex];

          /*  const areaVal = (field === 'roomType') ? value
                : product.roomType + (field === 'areaDesc')Korea 
                ? value: product.areaDesc;*/
                
            // ✅ KEY MUST USE Area/RoomType, not any random field value
        const areaVal = (field === 'roomType') ? value : product.roomType;
        const newKey = `${product.id || ''}_${areaVal || 'default'}_${product.description || ''}`;
        product.compositeKey = newKey;

            this.calculatePrices(productIndex);
            this.selectedProducts = [...this.selectedProducts];
        }
    }

        calculatePrices(productIndex) {
            const product = this.selectedProducts [productIndex];
            console.log(product.isNaturalStone);
     //    alert(JSON.stringify(product));   
            if (product.isNaturalStone) {
                // Natural Stone calculation: discount on before-tax price, then add tax
                const unitPrice = parseFloat(product.unitPrice) || 0;
                                const taxPercent = parseFloat(product.Tax) || 0;
                const requiredSqft = parseFloat(product.requiredSqft) || 0;
                const discType = product.discType || 'Percentage';
                const discValue = parseFloat(product.discValue) || 0;

                // 1. Apply discount on BEFORE-tax unit price
                let afterDiscPriceWithoutTax = unitPrice;
                if (discType === 'Percentage' && discValue > 0) {
                    afterDiscPriceWithoutTax = unitPrice * (1 - discValue / 100);
                } else if (discType === 'Amount' && discValue > 0) {
                    afterDiscPriceWithoutTax = Math.max(unitPrice - discValue, 0);
                }

                // 2. Add tax on top of the discounted before-tax price
                const afterDiscPrice = afterDiscPriceWithoutTax * (1 + taxPercent / 100);

                // 3. Total (after tax)
                const totalPrice = afterDiscPrice * requiredSqft;

                product.afterDiscPrice = afterDiscPrice.toFixed(6);
                  product.afterDiscPriceWithoutTax = afterDiscPriceWithoutTax.toFixed(6);
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
                // 1a. Unit Price Without Tax
                const unitPriceWithoutTax = unitPrice;

                // 2. Price per Sqft (with and without tax)
                let pricePerSqft = 0;
                let pricePerSqftWithoutTax = 0;
                if (sqftPerPiece > 0) {
                    pricePerSqft = parseFloat((unitPriceAfterTax / sqftPerPiece).toFixed(6));
                    pricePerSqftWithoutTax = parseFloat((unitPriceWithoutTax / sqftPerPiece).toFixed(6));
                }

                // 3. Apply discount on the BEFORE-tax per-sqft price, then add tax
                let afterDiscPriceSqftWithoutTax = pricePerSqftWithoutTax;
                let afterDiscPriceUnitWithoutTax = unitPriceWithoutTax;

                if (discType === 'Percentage' && discValue > 0) {
                    afterDiscPriceSqftWithoutTax = parseFloat((pricePerSqftWithoutTax * (1 - discValue / 100)).toFixed(6));
                    afterDiscPriceUnitWithoutTax = afterDiscPriceSqftWithoutTax * sqftPerPiece;
                } else if (discType === 'Amount' && discValue > 0) {
                    afterDiscPriceSqftWithoutTax = parseFloat(Math.max(pricePerSqftWithoutTax - discValue, 0).toFixed(6));
                    afterDiscPriceUnitWithoutTax = afterDiscPriceSqftWithoutTax * sqftPerPiece;
                }

                // 4. Add tax on top of the discounted before-tax price
                const afterDiscPriceSqft = parseFloat((afterDiscPriceSqftWithoutTax * (1 + taxPercent / 100)).toFixed(6));
                const afterDiscPriceUnit = afterDiscPriceSqft * sqftPerPiece;

                // 5. Total Amount (use the after discount price per sqft)
                const totalPrice = parseFloat((afterDiscPriceSqft * finalSqft).toFixed(6));
                product.unitPriceAfterTax = unitPriceAfterTax.toFixed(6);
                product.pricePerSqft = pricePerSqft.toFixed(6); // always show original after-tax per sqft
                product.afterDiscPriceSqft = afterDiscPriceSqft.toFixed(6); // always from original
                product.totalPrice = totalPrice.toFixed(2);
                product.afterDiscPriceUnit = afterDiscPriceUnit.toFixed(6);
                // New: set without tax fields
            //    product.pricePerSqftWithoutTax = pricePerSqftWithoutTax.toFixed(6);
                product.afterDiscPriceSqftWithoutTax = afterDiscPriceSqftWithoutTax.toFixed(6);
                product.afterDiscPriceUnitWithoutTax = afterDiscPriceUnitWithoutTax.toFixed(6);
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
            // 1a. Unit Price Without Tax
            const unitPriceWithoutTax = unitPrice;
            // 2. Apply discount on the BEFORE-tax unit price
            let afterDiscPricePieceWithoutTax = unitPriceWithoutTax;
            if (discType === 'Percentage' && discValue > 0) {
                afterDiscPricePieceWithoutTax = unitPriceWithoutTax * (1 - discValue / 100);
            } else if (discType === 'Amount' && discValue > 0) {
                afterDiscPricePieceWithoutTax = Math.max(unitPriceWithoutTax - discValue, 0);
            }
            // 3. Add tax on top of the discounted before-tax price
            const afterDiscPricePiece = afterDiscPricePieceWithoutTax * (1 + taxPercent / 100);
            // 4. Total
            const totalPrice = afterDiscPricePiece * quantity;
            product.unitPriceAfterTax = unitPriceAfterTax.toFixed(2);
            product.afterDiscPricePiece = afterDiscPricePiece.toFixed(6);
            product.afterDiscPricePieceWithoutTax = afterDiscPricePieceWithoutTax.toFixed(6);
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

        handleCheckStock(event) {
            const index = event.target.dataset.index;
            const item = this.selectedProducts[index];
            const productId = event.target.dataset.productId;
            if (!item.code) {
                return;
            }
            
            if (item.stockList && item.stockList.length > 0) {
                item.stockChecked = true;
                this.selectedProducts = [...this.selectedProducts];
                return;
            }

            checkLiveStock({ itemcode: item.code })
                .then(result => {
                    this.warehouseStockList = result;
                this.updateProduct(productId, 'stockList', result,index);
                this.updateProduct(productId, 'stockChecked', true,index);
                console.error('this.selectedProducts', JSON.stringify(this.selectedProducts));
                })
                .catch(error => {
                    console.error('Stock check failed', error);
                });
        }

        handleCloseStockPopup(event) {
                const index = event.target.dataset.index;
                this.selectedProducts[index].stockChecked = false;
                this.selectedProducts = [...this.selectedProducts];
        }
 
    handlePreview() {

        
        if (!this.selectedProducts || this.selectedProducts.length === 0) {
            this.showError('No products added to preview');
        return;
    }
console.log('Selected products for preview:', JSON.stringify(this.selectedProducts));
//duplicate removed as client req: 2/4/26
 /*  const validRows = this.selectedProducts
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
    */
    // VALIDATION LOOP
    for (let item of this.selectedProducts) {
        if ((!item.roomType || item.roomType.trim() === '') && item.category!='ADHESIVE') {
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
        return {
            ...item,
            discountSymbol: item.discType === 'Percentage' ? '%' : '\u20b9',
            unitPriceDisplay,
            afterDiscDisplay,
            lineTotalDisplay: Number(lineTotalDisplay).toFixed(2)
        };
    });
this.recalculateOrderTotal();

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
    handleroundOffChargeChange(event) {
            let value = Number(event.target.value) || 0;

        if (value > 15) {
            value = 15;
        }

        if (value < 0) {
            value = 0;
        }
        this.roundOff = value;

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
                        message: 'No Opp ID found. Please start from a Opp record.',
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
            this.isConfirmed = true;
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
                    msp: item.msp,  
                    priceSqft: item.priceSqft,                 // fallback
                    discType: item.discType,
                    discValue: item.discValue,
                    uom: item.uom,
                    sqft: item.sqft || 0,
                    sqm: item.sqm || 0,
                 afterDiscPrice: item.afterDiscPrice,
                    afterDiscPriceWithoutTax: item.afterDiscPriceWithoutTax,
                    afterDiscPricePiece: item.afterDiscPricePiece,
                    afterDiscPriceSqft: item.afterDiscPriceSqft,
                    afterDiscPricePieceWithoutTax: item.afterDiscPricePieceWithoutTax,
                    afterDiscPriceSqftWithoutTax: item.afterDiscPriceSqftWithoutTax,
                       afterDiscPriceUnitWithoutTax: item.afterDiscPriceUnitWithoutTax,
                    price: item.unitPrice,
                    discount: item.discValue,
                    totalPrice: item.totalPrice,
                    roomType: item.roomType,
                    areaDesc: item.areaDesc,
                    description: item.description,
                    requiredSqft: item.requiredSqft,
                    pricebookEntryId: item.pricebookEntryId,
                     showDropdown: false,
                     isTile: item.isTile,
                 isActive: false,
                rowClass: 'item-card'
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
                roundOff: this.roundOff || 0,
                pbName :this.selectedPB,
                orderTotal : this.orderTotal || 0,
                category : this.selectedCategory
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
                    objectApiName: 'Quote',
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
              this.isConfirmed = false;
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



        // ── Touch handling for search results (prevents scroll = select on mobile) ──
        _touchStartY = 0;
        _touchMoved = false;

        handleTouchStart(event) {
            this._touchStartY = event.touches[0].clientY;
            this._touchMoved = false;
        }

        handleTouchMove() {
            this._touchMoved = true;
        }

        handleTouchEnd(event) {
            // Only select if the user tapped (did not scroll)
            if (!this._touchMoved) {
                this.handleSearchResultClick(event);
            }
        }

        handleSearchFocus(event) {
            // optional: set activeRowIndex when the input gets focus
            const idx = event.currentTarget.dataset.index;
            this.activeRowIndex = typeof idx !== 'undefined' ? Number(idx) : null;
        }

        handleClearSearch(event) {
            event.stopPropagation();
            const index = Number(event.currentTarget.dataset.index);
            const updated = [...this.selectedProducts];
            updated[index] = {
                ...updated[index],
                id: '',
                name: '',
                code: '',
                quantity: 0,
                unitPrice: 0,
                msp: 0,
                unitPriceAfterTax: 0,
                afterDiscPricePiece: 0,
                afterDiscPriceSqft: 0,
                afterDiscPriceUnit: 0,
                                afterDiscPrice: 0,
                afterDiscPriceWithoutTax: 0,
                pricePerSqft: 0,
                totalPrice: 0,
                description: '',
                discType: 'Amount',
                discValue: 0,
                requiredSqft: 0,
                sqft: 0,
                sqm: 0,
                sqftPerPiece: 0,
                Tax: 0,
                pricebookEntryId: '',
                isNaturalStone: false,
                isTile: false,
                stockChecked: false,
                stockList: [],
                showDropdown: false
            };
            this.selectedProducts = updated;
            this.searchResults = [];
            this.showSearchDropdown = false;
            this.recalculateOrderTotal();
        }

        handleSearchBlur() {
        setTimeout(() => {
            this.selectedProducts = this.selectedProducts.map(row => ({
                ...row,
                showDropdown: false
            }));
            this.showSearchDropdown = false;
        }, 200);
    }



        handleSearchInput(event) {
            const index = Number(event.target.dataset.index);
            const value = event.target.value;

            this.activeRowIndex = index;

            // Update the row's name so the input reflects the user's typing
            const updated = [...this.selectedProducts];
            updated[index] = { ...updated[index], name: value };
            // If user clears or changes text, reset the selected product for this row
            if (updated[index].id && value !== updated[index].code) {
                updated[index].id = '';
                updated[index].code = '';
                updated[index].stockChecked = false;
            }
            this.selectedProducts = updated;

            if (!value || value.length < 2) {
                this.searchResults = [];
                this.selectedProducts = this.selectedProducts.map((row, i) => ({
                    ...row,
                    showDropdown: i === index ? false : row.showDropdown
                }));
                return;
            }

            const rowCategory = this.selectedProducts[index].category;

            if (!rowCategory) {
                this.showError('Please select category first');
                return;
            }

            if (!this.selectedPB) {
                this.showError('Please select Pricebook first');
                return;
            }

            if (this.searchTimeout) {
                clearTimeout(this.searchTimeout);
            }

            this.searchTimeout = setTimeout(() => {

                getProducts({
                    category: rowCategory,
                    searchKey: value,
                    pricebookName: this.selectedPB
                })
                .then(result => {
                    this.searchResults = result || [];

                    this.selectedProducts = this.selectedProducts.map((row, i) => ({
                        ...row,
                        showDropdown: i === index
                    }));
                })
                .catch(error => {
                    console.error(error);
                });

            }, 400);
        }





handleSearchResultClick(event) {
      const productId1 = event.currentTarget.dataset.productId;
    const rowIndex1 = event.currentTarget.dataset.index;

    console.log('Selected Product Id:', productId1);
    console.log('Row Index:', rowIndex1);

    // find clicked element (works even if inner child was clicked)
    const el = event.target.closest('[data-product-id]');
    if (!el) return;
console.log(el);
    const productId = el.dataset.productId;
    // find the product in the same array you rendered
    const selectedProduct = (this.searchResults || []).find(p => String(p.Id) === String(productId))
                         || (this.products || []).find(p => String(p.Id) === String(productId));

    if (!selectedProduct) {
      console.warn('product not found for id', productId);
      return;
    }

   // const unitPrice = this.pbEntryMap?.get(selectedProduct.Id) || 0;
    //const pricebookEntryId = this.pbEntryIdMap?.get(selectedProduct.Id) || '';

        const unitPrice =selectedProduct.unitPrice;
    const pricebookEntryId = selectedProduct.pricebookEntryId;

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
        updated[this.activeRowIndex].code = selectedProduct.productCode;
        updated[this.activeRowIndex].category = selectedProduct.category || '';
        updated[this.activeRowIndex].isNaturalStone= selectedProduct.category === 'N.STONE';
        updated[this.activeRowIndex].quantity= selectedProduct.category === 'N.STONE' ? 1:0;

        updated[this.activeRowIndex].isTile= selectedProduct.category === 'TILE';
        
        updated[this.activeRowIndex].showDropdown = false;
         updated[this.activeRowIndex].msp = selectedProduct.msp;
        updated[this.activeRowIndex].unitPrice = unitPrice;
        updated[this.activeRowIndex].priceSqft = unitPrice;
        updated[this.activeRowIndex].pricebookEntryId = pricebookEntryId;
        updated[this.activeRowIndex].sqftPerPiece=selectedProduct.sqftPiece;
        updated[this.activeRowIndex].Tax=selectedProduct.tax;

        // Calculate mspInSqft for tiles: (msp + tax%) / sqftPerPiece
        if (updated[this.activeRowIndex].isTile) {
            const msp = parseFloat(selectedProduct.msp) || 0;
            const tax = parseFloat(selectedProduct.tax) || 0;
            const sqftPerPiece = parseFloat(selectedProduct.sqftPiece) || 0;
            updated[this.activeRowIndex].mspInSqft = sqftPerPiece > 0
               //
                 ? parseFloat(((msp ) / sqftPerPiece).toFixed(6)): 0;
        } else {
            updated[this.activeRowIndex].mspInSqft = 0;
        }
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
            this.updateProduct(productId, 'quantity', quantity,idx);
            
            // Calculate actual sqft based on the rounded up quantity
            const actualSqft = quantity * product.sqftPerPiece;
            this.updateProduct(productId, 'sqft', actualSqft,idx);
            
            // Calculate sqm (1 sqft = 0.092903 sqm)
            const sqm = actualSqft * 0.092903;
            this.updateProduct(productId, 'sqm', sqm.toFixed(2),idx);
        }
    }

    handleRoomTypeChange(event) {
    const productId = event.target.dataset.productId;
    const idx = event.target.dataset.index;
    const value = event.detail.value;   

    this.updateProduct(productId, 'roomType', value, idx);
}


handleAreaDesChange(event) {
    const productId = event.target.dataset.productId;
    const idx = event.target.dataset.index;
    const value = event.detail.value;   

    this.updateProduct(productId, 'areaDesc', value, idx);
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
            const taxPercent = parseFloat(product.Tax) || 0;

            const unitPrice = parseFloat(product.unitPrice) || 0;
            const requiredSqft = parseFloat(product.requiredSqft) || 0;
            const discType = product.discType || 'Percentage';

            const discValue = parseFloat(product.discValue) || 0;
            
            // Apply discount on BEFORE-tax unit price, then add tax
            let afterDiscPriceWithoutTax = unitPrice;

            if (discType === 'Percentage' && discValue > 0) {
                const discountMultiplier = 1 - (discValue / 100);
                afterDiscPriceWithoutTax = unitPrice * discountMultiplier;
            } else if (discType === 'Amount' && discValue > 0) {
                afterDiscPriceWithoutTax = Math.max(unitPrice - discValue, 0);
            }

            const afterDiscPrice = afterDiscPriceWithoutTax * (1 + taxPercent / 100);
            const totalPrice = afterDiscPrice * requiredSqft;


            // Update only if values have changed
            if (product.afterDiscPrice !== Number(afterDiscPrice).toFixed(2)) {
                this.updateProduct(productId, 'afterDiscPrice', Number(afterDiscPrice).toFixed(2),idx);
            }
                        this.updateProduct(productId, 'afterDiscPriceWithoutTax', Number(afterDiscPriceWithoutTax).toFixed(6),idx);

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
             event.stopPropagation();
            const index = event.target.dataset.index;
            this.addItemRecord(index);
           /* setTimeout(() => {
            const container = this.template.querySelector('[data-id="scrollContainer"]');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
            }, 50);*/
            
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
            let items = this.selectedProducts.map(item => {
        return {
            ...item,
            isActive: false,
            rowClass: 'item-card'
        };
    });

      //  let items = [...this.selectedProducts];
        //      if (index === -1) {

          const newItem = {
        compositeKey: `${Date.now()}_${Math.random()}`,
            lineNo:index+1,
                    id: '',
                    
                    name: '',
                    code: '',
                    category: this.selectedProducts[index]?.category || '',
                    quantity: 0,
                    unitPrice:0,
                    msp:0,
                    afterDiscPricePiece:  0,
                                        afterDiscPrice: 0,
                    afterDiscPriceWithoutTax: 0,
                    totalPrice: 0,
                    description: '',
                    discType: 'Amount',
                    discValue: 0,
                    roomType: '',
                    areaDesc: '',
                    requiredSqft: 0,
                    pricePerSqft: 0,
                    afterDiscPriceSqft: 0,
                    sqft: 0, sqm: 0,
                    pricebookEntryId:'',
                     isNaturalStone: false,
                      isTile: false,
                    showDropdown: false,
                isActive: true,
                rowClass: 'item-card active'
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
                (parseFloat(this.unloadingCharge) || 0) -
                 (parseFloat(this.roundOff) || 0) 
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
            this.updateLineNumbers();
            this.draggedIndex = null;
        }

        // ── Touch-based drag-and-drop for mobile ──
        _touchDragIndex = null;
        _touchStartY = 0;
        _touchDragMoved = false;
        _lastTouchOverIndex = null;

        handleRowTouchStart(event) {
            const row = event.currentTarget;
            this._touchDragIndex = Number(row.dataset.index);
            this._touchStartY = event.touches[0].clientY;
            this._touchDragMoved = false;
            this._lastTouchOverIndex = null;

            // Long-press delay — start drag after 200ms hold
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._touchDragTimer = setTimeout(() => {
                this._touchDragMoved = true;
                row.classList.add('dragging');
            }, 200);
        }

        handleRowTouchMove(event) {
            if (!this._touchDragMoved) {
                // If finger moved before long-press fired, cancel drag
                const dy = Math.abs(event.touches[0].clientY - this._touchStartY);
                if (dy > 10 && this._touchDragTimer) {
                    clearTimeout(this._touchDragTimer);
                    this._touchDragTimer = null;
                }
                return;
            }

            event.preventDefault(); // prevent page scroll while dragging

            const touch = event.touches[0];
            const targetEl = this.template.elementFromPoint
                ? this.template.elementFromPoint(touch.clientX, touch.clientY)
                : document.elementFromPoint(touch.clientX, touch.clientY);

            if (!targetEl) return;

            const tr = targetEl.closest('tr.cart-item');
            if (!tr) return;

            const overIndex = Number(tr.dataset.index);

            // Remove previous drag-over highlight
            if (this._lastTouchOverIndex !== null && this._lastTouchOverIndex !== overIndex) {
                const rows = this.template.querySelectorAll('tr.cart-item');
                rows.forEach(r => r.classList.remove('drag-over'));
            }

            if (overIndex !== this._touchDragIndex) {
                tr.classList.add('drag-over');
                this._lastTouchOverIndex = overIndex;
            }
        }

        handleRowTouchEnd() {
            // Clear long-press timer
            if (this._touchDragTimer) {
                clearTimeout(this._touchDragTimer);
                this._touchDragTimer = null;
            }

            // Clean up CSS classes
            const rows = this.template.querySelectorAll('tr.cart-item');
            rows.forEach(r => {
                r.classList.remove('dragging');
                r.classList.remove('drag-over');
            });

            if (!this._touchDragMoved || this._lastTouchOverIndex === null) {
                this._touchDragIndex = null;
                return;
            }

            const fromIndex = this._touchDragIndex;
            const toIndex = this._lastTouchOverIndex;

            if (fromIndex !== toIndex) {
                const items = [...this.selectedProducts];
                const draggedItem = items.splice(fromIndex, 1)[0];
                items.splice(toIndex, 0, draggedItem);
                this.selectedProducts = items;
                this.updateLineNumbers();
            }

            this._touchDragIndex = null;
            this._lastTouchOverIndex = null;
            this._touchDragMoved = false;
        }


    }