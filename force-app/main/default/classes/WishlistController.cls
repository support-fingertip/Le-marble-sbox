public with sharing class WishlistController {
    @AuraEnabled
    public static Wishlist_Item__c addToWishlist(Id productId, Id opportunityId) {
        try {
            System.debug('=== Starting addToWishlist ===');
            System.debug('Input parameters:');
            System.debug('ProductId: ' + productId);
            System.debug('DealId: ' + opportunityId);
            
            if(productId == null) {
                System.debug('Error: ProductId is null');
                throw new AuraHandledException('Product ID is required.');
            }

            if(opportunityId == null) {
                System.debug('Error: DealId is null');
                throw new AuraHandledException('Deal ID is required.');
            }

            // Check if the product exists
            System.debug('Checking if product exists...');
            List<Product__c> products = [SELECT Id, Name FROM Product__c WHERE Id = :productId LIMIT 1];
            if(products.isEmpty()) {
                System.debug('Error: Product not found with ID: ' + productId);
                throw new AuraHandledException('Product not found with ID: ' + productId);
            }
            System.debug('Product found: ' + products[0].Name);

            // Check if the deal exists
            System.debug('Checking if deal exists...');
            List<Deals__c> deals = [SELECT Id, Name FROM Deals__c WHERE Id = :opportunityId LIMIT 1];
            if(deals.isEmpty()) {
                System.debug('Error: Deal not found with ID: ' + opportunityId);
                throw new AuraHandledException('Deal not found with ID: ' + opportunityId);
            }
            System.debug('Deal found: ' + deals[0].Name);

            // Check if the product is already in the wishlist
            System.debug('Checking for existing wishlist items...');
            List<Wishlist_Item__c> existingItems = [
                SELECT Id 
                FROM Wishlist_Item__c 
                WHERE Product__c = :productId 
                AND Opportunity__c = :opportunityId
            ];
            
            if (!existingItems.isEmpty()) {
                System.debug('Error: Product already in wishlist');
                throw new AuraHandledException('This product is already in your wishlist.');
            }
            
            // Create new wishlist item
            System.debug('Creating new wishlist item...');
            Wishlist_Item__c newItem = new Wishlist_Item__c();
            
            try {
                newItem.Product__c = productId;
                newItem.Opportunity__c = opportunityId;
                newItem.OwnerId = UserInfo.getUserId();
                
                System.debug('Attempting to insert wishlist item: ' + newItem);
                insert newItem;
                System.debug('Wishlist item created successfully with ID: ' + newItem.Id);
                return newItem;
            } catch(DmlException de) {
                System.debug('DML Error: ' + de.getMessage());
                System.debug('DML Error Fields: ' + de.getDmlFieldNames(0));
                throw new AuraHandledException('Failed to create wishlist item: ' + de.getMessage());
            }
        } catch (Exception e) {
            System.debug('=== Error in addToWishlist ===');
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Wishlist_Item__c> getWishlistItems(Id opportunityId) {
        try {
            if(opportunityId == null) {
                throw new AuraHandledException('Opportunity ID is required.');
            }

            List<Wishlist_Item__c> items = [
                SELECT Id, Name, CreatedDate, Product__c, 
                       Product__r.Name,
                       Product__r.Product_Code__c, Product__r.MSP__c,
                       Product__r.MRP__c, Product__r.Product_Category__c,
                       Product__r.Product_Image__c, Product__r.UOM__c,
                       Product__r.Price_Sqft__c, Product__r.Size__c,
                       Product__r.Sqft_Piece__c,
                       CreatedById, LastModifiedById, OwnerId
                FROM Wishlist_Item__c
                WHERE Opportunity__c = :opportunityId
                ORDER BY CreatedDate DESC
            ];
            
            return items;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching wishlist items: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void removeFromWishlist(Id wishlistItemId) {
        try {
            if(wishlistItemId == null) {
                throw new AuraHandledException('Wishlist Item ID is required.');
            }

            List<Wishlist_Item__c> itemsToDelete = [
                SELECT Id 
                FROM Wishlist_Item__c 
                WHERE Id = :wishlistItemId
                LIMIT 1
            ];
            
            if(itemsToDelete.isEmpty()) {
                throw new AuraHandledException('Wishlist item not found.');
            }
            
            delete itemsToDelete[0];
        } catch (Exception e) {
            throw new AuraHandledException('Error removing item from wishlist: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createCartFromWishlistItems(List<Id> wishlistItemIds, Id opportunityId, 
                                                   List<Map<String, Object>> cartItems,
                                                   Decimal freightCharge, Decimal loadingCharge, 
                                                   Decimal unloadingCharge) {
        try {
            System.debug('=== Starting createCartFromWishlistItems ===');
            System.debug('Input parameters:');
            System.debug('WishlistItemIds: ' + wishlistItemIds);
            System.debug('OpportunityId: ' + opportunityId);
            System.debug('CartItems: ' + JSON.serialize(cartItems));
            System.debug('Charges - Freight: ' + freightCharge + ', Loading: ' + loadingCharge + ', Unloading: ' + unloadingCharge);

            // Validate Opportunity
            if(opportunityId == null) {
                System.debug('Error: OpportunityId is null');
                throw new AuraHandledException('Opportunity ID is required');
            }

            // Verify Opportunity exists
            List<Deals__c> deals = [SELECT Id, Name FROM Deals__c WHERE Id = :opportunityId LIMIT 1];
            if(deals.isEmpty()) {
                System.debug('Error: Opportunity not found with ID: ' + opportunityId);
                throw new AuraHandledException('Opportunity not found with ID: ' + opportunityId);
            }
            System.debug('Found Opportunity: ' + deals[0].Name);

            if(cartItems == null || cartItems.isEmpty()) {
                System.debug('Error: Cart items data is null or empty');
                throw new AuraHandledException('Cart items data is required');
            }

            // Start transaction
            Savepoint sp = Database.setSavepoint();
            try {
                // Create cart
                Cart__c newCart = new Cart__c(
                    Deals__c = opportunityId,
                    Status__c = 'Pending',
                    Freight_Charge__c = freightCharge != null ? freightCharge : 0,
                    Loading_Charge__c = loadingCharge != null ? loadingCharge : 0,
                    Unloading_Charge__c = unloadingCharge != null ? unloadingCharge : 0
                );
                
                try {
                    System.debug('Attempting to insert cart: ' + newCart);
                    insert newCart;
                    System.debug('Successfully created cart with ID: ' + newCart.Id);
                } catch(DmlException de) {
                    System.debug('Error creating cart: ' + de.getMessage());
                    System.debug('DML Error Fields: ' + de.getDmlFieldNames(0));
                    throw new AuraHandledException('Failed to create cart: ' + de.getMessage());
                }

                // Create cart line items
                List<Cart_Line_Item__c> lineItems = new List<Cart_Line_Item__c>();
                
                for(Map<String, Object> item : cartItems) {
                    try {
                        if(item == null || !item.containsKey('id')) {
                            System.debug('Skipping null item or item without product ID');
                            continue;
                        }

                        System.debug('Processing cart item: ' + JSON.serialize(item));

                        // Verify Product exists
                        String productId = (String)item.get('id');
                        List<Product__c> products = [SELECT Id, Name FROM Product__c WHERE Id = :productId LIMIT 1];
                        if(products.isEmpty()) {
                            System.debug('Error: Product not found with ID: ' + productId);
                            throw new AuraHandledException('Product not found with ID: ' + productId);
                        }
                        System.debug('Found Product: ' + products[0].Name);

                        // Log all price values before conversion
                        System.debug('Price values before conversion:');
                        System.debug('price: ' + item.get('price'));
                        System.debug('afterDiscPricePiece: ' + item.get('afterDiscPricePiece'));
                        System.debug('afterDiscPriceSqft: ' + item.get('afterDiscPriceSqft'));
                        System.debug('totalPrice: ' + item.get('totalPrice'));

                        Cart_Line_Item__c lineItem = new Cart_Line_Item__c(
                            Cart__c = newCart.Id,
                            Product__c = productId,
                            Product_Category__c = (String)item.get('category'),
                            Quantity__c = safeDecimalConversion(item.get('quantity')),
                            UOM__c = (String)item.get('uom'),
                            Unit_Price__c = safeDecimalConversion(item.get('unitPrice')),
                            Price_Sqft__c = safeDecimalConversion(item.get('priceSqft')),
                            Sqft__c = safeDecimalConversion(item.get('sqft')),
                            Sqm__c = safeDecimalConversion(item.get('sqm')),
                            Disc_Type__c = (String)item.get('discType'),
                            Dis_Value__c = safeDecimalConversion(item.get('discValue')),
                            Price__c = safeDecimalConversion(item.get('price')),
                            After_Disc_Price_Piece__c = safeDecimalConversion(item.get('afterDiscPricePiece')),
                            After_Disc_Price_Sqft__c = safeDecimalConversion(item.get('afterDiscPriceSqft'))
                        );
                        
                        System.debug('Created line item: ' + lineItem);
                        lineItems.add(lineItem);
                    } catch(Exception e) {
                        System.debug('Error processing cart item: ' + e.getMessage());
                        System.debug('Stack trace: ' + e.getStackTraceString());
                        if(item != null) {
                            System.debug('Cart item data: ' + JSON.serialize(item));
                        }
                        throw new AuraHandledException('Error processing cart item for product ' + 
                            (item != null && item.containsKey('id') ? item.get('id') : 'unknown') + 
                            ': ' + e.getMessage());
                    }
                }

                if(!lineItems.isEmpty()) {
                    try {
                        System.debug('Attempting to insert ' + lineItems.size() + ' line items');
                        insert lineItems;
                        System.debug('Successfully inserted line items');
                    } catch(DmlException de) {
                        System.debug('Error inserting line items: ' + de.getMessage());
                        System.debug('DML Error Fields: ' + de.getDmlFieldNames(0));
                        throw new AuraHandledException('Error inserting cart line items: ' + de.getMessage());
                    }
                }

                // Delete wishlist items if they exist
                if(wishlistItemIds != null && !wishlistItemIds.isEmpty()) {
                    List<Wishlist_Item__c> wishlistItems = [
                        SELECT Id, Product__c, Product__r.Product_Category__c, Product__r.Name
                        FROM Wishlist_Item__c
                        WHERE Id IN :wishlistItemIds
                    ];

                    if(!wishlistItems.isEmpty()) {
                        try {
                            System.debug('Attempting to delete ' + wishlistItems.size() + ' wishlist items');
                            delete wishlistItems;
                            System.debug('Successfully deleted wishlist items');
                        } catch(Exception e) {
                            System.debug('Error deleting wishlist items: ' + e.getMessage());
                            System.debug('Stack trace: ' + e.getStackTraceString());
                            // Don't throw here as the cart was created successfully
                        }
                    }
                }

                return newCart.Id;

            } catch(Exception e) {
                Database.rollback(sp);
                System.debug('Error in cart creation: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                throw new AuraHandledException('Failed to create cart: ' + e.getMessage());
            }
        } catch(Exception e) {
            System.debug('Error in createCartFromWishlistItems: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Helper method to safely convert values to Decimal
    private static Decimal safeDecimalConversion(Object val) {
        if(val == null) return 0;
        
        if(val instanceof Decimal) {
            return (Decimal)val;
        } else if(val instanceof Integer) {
            return Decimal.valueOf((Integer)val);
        } else if(val instanceof Double) {
            return Decimal.valueOf((Double)val);
        } else if(val instanceof String) {
            String strVal = (String)val;
            if(strVal.trim() == '') return 0;
            try {
                return Decimal.valueOf(strVal);
            } catch(Exception e) {
                System.debug('Error converting string to decimal: ' + strVal);
                return 0;
            }
        } else {
            String strVal = String.valueOf(val);
            if(strVal.trim() == '') return 0;
            try {
                return Decimal.valueOf(strVal);
            } catch(Exception e) {
                System.debug('Error converting value to decimal: ' + strVal);
                return 0;
            }
        }
    }
}