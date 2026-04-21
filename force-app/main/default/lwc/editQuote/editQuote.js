import { LightningElement, track, api,wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getQuoteLineItems from '@salesforce/apex/NewQuoteController.getQuoteLineItems';
import updateQuoteCart from '@salesforce/apex/NewQuoteController.updateQuoteCart';
import getProducts from '@salesforce/apex/NewQuoteController.getProducts';
import getPendingQuotes from '@salesforce/apex/NewQuoteController.getPendingQuotes';
import getPriceBookName from '@salesforce/apex/NewQuoteController.getPriceNames';
import getProductCategories from '@salesforce/apex/NewQuoteController.getProductCategories';
import checkLiveStock from '@salesforce/apex/NewQuoteController.checkLiveStock';
import getAreaPicklistValues from '@salesforce/apex/NewQuoteController.getAreaPicklistValues';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';


export default class Edit_Quote extends NavigationMixin(LightningElement) {
    
  //New_Quote_From_Opportunity
    @api recordId; 
     @track selectedCategory = '';
    @track selectedPB = '';
    @track isEditMode = false;
quoteId = null;
deletedQLIIds=[];
    pbEntries = [];
    pbEntryMap = new Map();
    pbEntryIdMap = new Map();
    @track isDropdownOpen = false;
    @track isLoading = false;
     @track isConfirmed = false;
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
    setCurrentPageReference(pageRef) {
    if (pageRef) {

        console.log('Navigation detected');

        this.pageRef = pageRef;

        // reset state when page opens again
        this.selectedProducts = [];
        this.searchResults = [];
        this.openPreview = false;

        // initialize again
        this.initializeRecordId();

        if (this.recordId) {
            this.checkPendingQuotes();
            this.tryLoadDefaultPricebook();
        }
    }
    }

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


        this.selectedProducts = [];
        localStorage.removeItem('selectedProducts');


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
                    { label: 'Select Pricebook', value: 'select' },
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
            console.log('Quote detected → Edit Mode');

            this.isEditMode = true;
            this.quoteId = this.recordId;

            this.loadQuoteItems();
    
         /*   getPBEntries({ pbName: this.selectedPB })
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

        loadQuoteItems(){

    getQuoteLineItems({quoteId:this.quoteId})

            .then(res=>{

            console.log('Quote Loaded',res);

            const quote = res.quoteRecord;
            const items = res.lineItems;

            /* HEADER VALUES */

            this.freightCharge = quote.Freight_Charge__c || 0;
            this.loadingCharge = quote.Loading_Charge__c || 0;
            this.unloadingCharge = quote.Unloading_Charge__c || 0;
            this.roundOff = quote.Round_Off__c || 0;

            /* PRICEBOOK */

            this.selectedPB = quote.PriceBook__c;

            console.log('Pricebook set from quote:',this.selectedPB);

            /* LINE ITEMS */

            this.selectedProducts = [];

            let i=0;

            items.forEach(item=>{

            i++;

            const cartItem={
            qliId:item.Id,
            lineNo:i,
            id:item.Product2Id,
            name:item.Product2.Name,
            code:item.Product2.Product_Code__c,
            category:item.Product2.Product_Category__c,
            quantity:item.Quantity,
            unitPrice:item.ListPrice,
            unitPriceAfterTax:item.UnitPrice,
            discType:item.Disc_Type__c,
            afterDiscPricePiece:item.After_Disc_Price_Piece__c,
            discValue:item.Dis_Value__c || 0,
                     afterDiscPricePieceWithoutTax: item.Product2.Product_Category__c === 'TILE'? 0:item.After_Discount_UOM_Price__c,
            afterDiscPriceSqftWithoutTax: 0,
            // TILE: MRP/Sqft input = Price_Sqft__c, After Disc/Sqft = After_Disc_Price_Sqft__c, After Disc/Unit = UnitPrice.
            // N.STONE: After Disc (₹) input = After_Disc_Price_Sqft__c.
            pricePerSqft: item.Product2.Product_Category__c === 'TILE' ? (item.Price_Sqft__c || 0) : 0,
            afterDiscPriceSqft: item.Product2.Product_Category__c === 'TILE' ? (item.After_Disc_Price_Sqft__c || 0) : 0,
            afterDiscPriceUnit: item.Product2.Product_Category__c === 'TILE' ? (item.UnitPrice || 0) : 0,
            afterDiscPrice: item.Product2.Product_Category__c === 'N.STONE' ? (item.After_Disc_Price_Sqft__c || 0) : 0,
            afterDiscPriceWithoutTax: item.Product2.Product_Category__c === 'N.STONE'? item.After_Discount_UOM_Price__c : 0,
            afterDiscPriceUnitWithoutTax: item.Product2.Product_Category__c === 'TILE'? item.After_Discount_UOM_Price__c : 0,
             roomType:item.Area__c,
            areaDesc:item.Room_Type__c,
            description:item.Description,
            requiredSqft:item.Sqft__c,
            sqft:item.Sqft__c,
            sqm:item.Sqm__c,
            pricebookEntryId:item.PricebookEntryId,
            totalPrice:item.TotalPrice,
            Tax:item.Product2.Tax__c || 0,
            sqftPerPiece:item.Product2.Sqft_Piece__c || 0,
            compositeKey:item.Id,
            msp:item.MSP__c,
            isNaturalStone:item.Product2.Product_Category__c === 'N.STONE',
            isTile:item.Product2.Product_Category__c === 'TILE',
            showDropdown:false,
            isActive:false,
            rowClass:'item-card'

            };

            this.selectedProducts.push(cartItem);
            console.error('cartItem', JSON.stringify(cartItem));
            });

            this.selectedProducts=[...this.selectedProducts];

            this.recalculateOrderTotal();

            })

            .catch(error=>{

            console.error('Error loading Quote',error);

            });

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
            this.calculatePrices(idx);
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
                console.log('product '+JSON.stringify(product));
                 console.log('product.discValue '+product.discValue);
                if (product && product.discValue !== discValue) {
            this.updateProduct(productId, 'discValue', discValue,idx);
             console.log('product.isNaturalStone111 ');
             console.log('product.isNaturalStone '+product.isNaturalStone);   
                    
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
console.log('product.compositeKey>>'+product.compositeKey);
            this.calculatePrices(productIndex);
            this.selectedProducts = [...this.selectedProducts];
        }
    }

        calculatePrices(productIndex) {
            console.log('productIndex:', productIndex);
            const product = this.selectedProducts[productIndex];
            // Natural Stone
            if (product.isNaturalStone) {
                const unitPrice = parseFloat(product.unitPrice) || 0;
                 const taxPercent = parseFloat(product.Tax) || 0;
                const requiredSqft = parseFloat(product.requiredSqft) || 0;
                const discType = product.discType || 'Percentage';
                const discValue = parseFloat(product.discValue) || 0;
                let afterDiscPrice = unitPrice;
                let totalPrice = unitPrice * requiredSqft;
                if (discType === 'Percentage' && discValue > 0) {
                    afterDiscPrice = unitPrice * (1 - discValue / 100);
                    totalPrice = afterDiscPrice * requiredSqft;
                } else if (discType === 'Amount' && discValue > 0) {
                    afterDiscPrice = Math.max(unitPrice - discValue, 0);
                    totalPrice = afterDiscPrice * requiredSqft;
                }
                     const afterDiscPriceWithoutTax = taxPercent > 0
                    ? parseFloat((afterDiscPrice / (1 + taxPercent / 100)).toFixed(6))
                    : afterDiscPrice;
                product.afterDiscPrice = afterDiscPrice.toFixed(6);
                  product.afterDiscPriceWithoutTax = afterDiscPriceWithoutTax.toFixed(6);
                product.totalPrice = totalPrice.toFixed(2);
                this.selectedProducts = [...this.selectedProducts];

                return;
            }
  console.log('product.isTile:', product.isTile);
 
            // TILES
            if (product.isTile) {
                const unitPrice = parseFloat(product.unitPrice) || 0;
                const taxPercent = parseFloat(product.Tax) || 0;
                const sqftPerPiece = parseFloat(product.sqftPerPiece) || 0;
                const finalSqft = parseFloat(product.requiredSqft) || 0;
                const quantity = parseFloat(product.quantity) || 0;
                const discType = product.discType || 'Percentage';
                const discValue = parseFloat(product.discValue) || 0;
console.log('discValue.>>>>:', discValue);  
                // With tax
                const unitPriceAfterTax = unitPrice * (1 + taxPercent / 100);
                let pricePerSqft = 0;
                if (sqftPerPiece > 0) {
                    pricePerSqft = parseFloat((unitPriceAfterTax / sqftPerPiece).toFixed(6));
                }
  console.log('pricePerSqft.>>>>:', pricePerSqft);               
              const unitPriceWithoutTax = unitPrice;
                let afterDiscPriceSqft = pricePerSqft;
                let afterDiscPriceUnit = unitPriceAfterTax;
                console.log('discType.>>>>:', discType);  
                 let afterDiscPricePieceWithoutTax = unitPriceWithoutTax;
                if (discType === 'Percentage' && discValue > 0) {
                    afterDiscPriceSqft = parseFloat((pricePerSqft * (1 - discValue / 100)).toFixed(6));
                    afterDiscPriceUnit = afterDiscPriceSqft * sqftPerPiece;
  console.log('afterDiscPriceUnit.>>>>:', afterDiscPriceUnit);                   
                         afterDiscPricePieceWithoutTax = unitPriceWithoutTax * (1 - discValue / 100);
                } else if (discType === 'Amount' && discValue > 0) {
                     console.log('1.>>>>:', discValue);  
                    afterDiscPriceSqft = parseFloat((pricePerSqft - discValue).toFixed(6));
                    afterDiscPriceUnit = afterDiscPriceSqft * sqftPerPiece;
                     console.log('afterDiscPriceUnit.>>>>:', afterDiscPriceUnit);  
                       afterDiscPricePieceWithoutTax = Math.max(unitPriceWithoutTax - discValue, 0);
                         console.log('afterDiscPriceUnitAmount.>>>>:', afterDiscPriceUnit);                   

                }

                const totalPrice = parseFloat((afterDiscPriceSqft * finalSqft).toFixed(6));
                product.unitPriceAfterTax = unitPriceAfterTax.toFixed(6);
                product.pricePerSqft = pricePerSqft.toFixed(6);
         console.log(' product.pricePerSqft.>>>>:',  product.pricePerSqft);           
                product.afterDiscPriceSqft = afterDiscPriceSqft.toFixed(6);
                product.totalPrice = totalPrice.toFixed(2);
                product.afterDiscPriceUnit = afterDiscPriceUnit.toFixed(6);
  console.log('totalPrice.>>>>:', totalPrice);
                // Without tax
                let pricePerSqftWithoutTax = 0;
                if (sqftPerPiece > 0) {
                    pricePerSqftWithoutTax = parseFloat((unitPriceWithoutTax / sqftPerPiece).toFixed(6));
                }
                let afterDiscPriceSqftWithoutTax = pricePerSqftWithoutTax;
                if (discType === 'Percentage' && discValue > 0) {
                    afterDiscPriceSqftWithoutTax = parseFloat((pricePerSqftWithoutTax * (1 - discValue / 100)).toFixed(6));
                } else if (discType === 'Amount' && discValue > 0) {
                    afterDiscPriceSqftWithoutTax = parseFloat((pricePerSqftWithoutTax - discValue).toFixed(6));
                }
                product.afterDiscPriceSqftWithoutTax = afterDiscPriceSqftWithoutTax.toFixed(6);
                         product.afterDiscPriceUnitWithoutTax = (afterDiscPriceSqftWithoutTax * sqftPerPiece).toFixed(6);
                this.selectedProducts = [...this.selectedProducts];

                return;
            }
            // OTHER CATEGORIES
            const unitPrice = parseFloat(product.unitPrice) || 0;
            const taxPercent = parseFloat(product.Tax) || 0;
            const quantity = parseFloat(product.quantity) || 0;
            const discType = product.discType || 'Percentage';
            const discValue = parseFloat(product.discValue) || 0;
            const unitPriceAfterTax = unitPrice * (1 + taxPercent / 100);
            const unitPriceWithoutTax = unitPrice;
            let afterDiscPricePiece = unitPriceAfterTax;
            let afterDiscPricePieceWithoutTax = unitPriceWithoutTax;
            if (discType === 'Percentage' && discValue > 0) {
                afterDiscPricePiece = unitPriceAfterTax * (1 - discValue / 100);
                afterDiscPricePieceWithoutTax = unitPriceWithoutTax * (1 - discValue / 100);
            } else if (discType === 'Amount' && discValue > 0) {
                afterDiscPricePiece = Math.max(unitPriceAfterTax - discValue, 0);
                afterDiscPricePieceWithoutTax = Math.max(unitPriceWithoutTax - discValue, 0);
            }

            console.log('afterDiscPricePieceWithoutTax:', afterDiscPricePieceWithoutTax);
            const totalPrice = afterDiscPricePiece * quantity;
            product.unitPriceAfterTax = unitPriceAfterTax.toFixed(2);
            product.afterDiscPricePiece = afterDiscPricePiece.toFixed(6);
            product.afterDiscPricePieceWithoutTax = afterDiscPricePieceWithoutTax.toFixed(6);
            product.totalPrice = totalPrice.toFixed(2);
    
            this.selectedProducts = [...this.selectedProducts];
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

//duplicate removed as client req 7/4/26
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
} */
    
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
        return {
            ...item,
            discountSymbol: item.discType === 'Percentage' ? '%' : '\u20b9',
            unitPriceDisplay,
            afterDiscDisplay,
            lineTotalDisplay: Number(lineTotalDisplay).toFixed(2)
        };
    });
this.recalculateOrderTotal();
console.log('Prepared items for preview:', JSON.stringify(this.selectedProducts));
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

            // Prepare cart items with only the necessary data to minimize payload size
            const cartItems = this.selectedProducts.map(item => {
                return {
                    id: item.id,
                    qliId: item.qliId || null, // include QLI Id for existing items, null for new
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
                 isActive: false,
                rowClass: 'item-card'
                };
            });

            console.log('Sending Quote items to server:', JSON.stringify(cartItems));

            // Create cart and cart line items
            let cartId;


    cartId = await updateQuoteCart({

        quoteId: this.quoteId,
        cartItems: cartItems,
        deletedQLIIds: this.deletedQLIIds,
        freightCharge: this.freightCharge || 0,
        loadingCharge: this.loadingCharge || 0,
        unloadingCharge: this.unloadingCharge || 0,
        roundOff: this.roundOff || 0,
        pbName: this.selectedPB,
        orderTotal: this.orderTotal || 0,
        category: this.selectedCategory

    });




            // Show success message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                   message:  'Quote updated successfully' ,
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
                afterDiscPricePieceWithoutTax: 0,
                afterDiscPriceSqftWithoutTax: 0,
                afterDiscPriceUnitWithoutTax: 0,
                  
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

    const unitPrice =selectedProduct.unitPrice;
    const pricebookEntryId = selectedProduct.pricebookEntryId;
    //this.pbEntryIdMap?.get(selectedProduct.Id) || '';

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

        // Calculate mspInSqft for tiles: msp / sqftPerPiece (no tax for MSP)
        if (updated[this.activeRowIndex].isTile) {
            const msp = parseFloat(selectedProduct.msp) || 0;
            const sqftPerPiece = parseFloat(selectedProduct.sqftPiece) || 0;
            updated[this.activeRowIndex].mspInSqft = sqftPerPiece > 0 ? parseFloat((msp / sqftPerPiece).toFixed(6)) : 0;
        } else {
            updated[this.activeRowIndex].mspInSqft = 0;
        }
        updated[this.activeRowIndex].totalPrice =
            (updated[this.activeRowIndex].quantity || 0) * unitPrice;
        updated[this.activeRowIndex].isRegularProduct = (!updated[this.activeRowIndex].isTile && !updated[this.activeRowIndex].isNaturalStone);

       console.log('handleSearchResultClick>>'+JSON.stringify(updated));
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
                  const afterDiscPriceWithoutTax = taxPercent > 0
                ? parseFloat((afterDiscPrice / (1 + taxPercent / 100)).toFixed(6))
                : afterDiscPrice;

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
     

       const removedItem = items[index];

        // If record exists in DB, store Id for deletion
        if (removedItem && removedItem.qliId) {
            this.deletedQLIIds.push(removedItem.qliId);
        }


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
                      afterDiscPricePieceWithoutTax: 0,
                    afterDiscPriceSqftWithoutTax: 0,
                          afterDiscPriceUnitWithoutTax: 0,
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
        
        
    }