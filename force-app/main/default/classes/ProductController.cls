/**
* @File Name : ProductController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : March 5, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | March 5, 2025 |   | Initial Version
**/

public with sharing class ProductController {
    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts() {
        try {
            return [
                SELECT 
                    Id,
                    Name,
                    Product_Code__c,
                    MSP__c,
                    MRP__c,
                    Product_Category__c,
                    Product_Image__c,
                    UOM__c,
                    Price_Sqft__c,
                    Sqft_Piece__c,
                    Size__c,
                    CreatedById,
                    LastModifiedById,
                    OwnerId,
                    In_Stock__c,
                    Tax__c
                FROM Product__c
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getProductCategories() {
        try {
            Schema.DescribeFieldResult fieldResult = Product__c.Product_Category__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            List<String> categories = new List<String>();
            
            for(Schema.PicklistEntry pickListVal : ple) {
                categories.add(pickListVal.getLabel());
            }
            
            return categories;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Method to create cart and cart line items
    @AuraEnabled
    public static String createCart(String customerId, List<Map<String, Object>> cartItems, 
                                   Decimal freightCharge, Decimal loadingCharge, 
                                   Decimal unloadingCharge) {
        try {
            System.debug('Creating cart for customerId: ' + customerId);
            System.debug('Cart items count: ' + (cartItems != null ? cartItems.size() : 0));
            System.debug('Freight: ' + freightCharge + ', Loading: ' + loadingCharge + ', Unloading: ' + unloadingCharge);
            
            // Create new Cart record
            Cart__c cart = new Cart__c();
            
            // Determine if ID is for Lead or Opportunity based on prefix
            String idPrefix = customerId.substring(0, 3);
            System.debug('ID Prefix: ' + idPrefix);
            
            // Set appropriate lookup field based on ID prefix
            if (idPrefix.equalsIgnoreCase('00Q')) {
                // Lead ID prefix
                cart.Customer__c = customerId;
            } else {
                // Default to Opportunity/Deal
                cart.Deals__c = customerId;
            }
            
            // Set other fields
            cart.Freight_Charge__c = freightCharge != null ? freightCharge : 0;
            cart.Loading_Charge__c = loadingCharge != null ? loadingCharge : 0;
            cart.Unloading_Charge__c = unloadingCharge != null ? unloadingCharge : 0;
            cart.Status__c = 'Pending'; // Use 'Pending' as the default status
            
            insert cart;
            System.debug('Cart created with ID: ' + cart.Id);

            // Create Cart Line Items if any items exist
            if (cartItems == null || cartItems.isEmpty()) {
                System.debug('No cart items to process');
                return cart.Id;
            }
            
            List<Cart_Line_Item__c> lineItems = new List<Cart_Line_Item__c>();
            
            for(Map<String, Object> item : cartItems) {
                try {
                    if (item == null || !item.containsKey('id')) {
                        System.debug('Skipping null item or item without product ID');
                        continue;
                    }
                    
                    Cart_Line_Item__c lineItem = new Cart_Line_Item__c(
                        Cart__c = cart.Id,
                        Product__c = (String)item.get('id')
                    );
                    
                    // Handle fields with safe conversion
                    if(item.containsKey('category')) {
                        lineItem.Product_Category__c = String.valueOf(item.get('category'));
                    }
                    
                    if(item.containsKey('quantity')) {
                        lineItem.Quantity__c = safeDecimalConversion(item.get('quantity'));
                    } else {
                        lineItem.Quantity__c = 1; // Default to 1 if missing
                    }
                    
                    if(item.containsKey('uom')) {
                        lineItem.UOM__c = String.valueOf(item.get('uom'));
                    }
                    
                    // For tiles, use unitPriceAfterTax and pricePerSqft
                    if(item.containsKey('unitPriceAfterTax')) {
                        lineItem.Unit_Price__c = safeDecimalConversion(item.get('unitPriceAfterTax'));
                    } else if(item.containsKey('unitPrice')) {
                        lineItem.Unit_Price__c = safeDecimalConversion(item.get('unitPrice'));
                    }
                    if(item.containsKey('pricePerSqft')) {
                        lineItem.Price_Sqft__c = safeDecimalConversion(item.get('pricePerSqft'));
                    } else if(item.containsKey('priceSqft')) {
                        lineItem.Price_Sqft__c = safeDecimalConversion(item.get('priceSqft'));
                    }
                    System.debug('DEBUG: LineItem.Unit_Price__c: ' + lineItem.Unit_Price__c);
                    System.debug('DEBUG: LineItem.Price_Sqft__c: ' + lineItem.Price_Sqft__c);
                    
                    if(item.containsKey('sqft')) {
                        lineItem.Sqft__c = safeDecimalConversion(item.get('sqft'));
                    }
                    
                    if(item.containsKey('sqm')) {
                        lineItem.Sqm__c = safeDecimalConversion(item.get('sqm'));
                    }
                    
                    if(item.containsKey('discType')) {
                        lineItem.Disc_Type__c = String.valueOf(item.get('discType'));
                    }
                    
                    if(item.containsKey('discValue')) {
                        lineItem.Dis_Value__c = safeDecimalConversion(item.get('discValue'));
                    }
                    
                    // Original discount field - may be needed for backward compatibility
                    if(item.containsKey('discount')) {
                        lineItem.Discount__c = safeDecimalConversion(item.get('discount'));
                    }
                    
                    // Original price field - may be needed for backward compatibility
                    if(item.containsKey('price')) {
                        lineItem.Price__c = safeDecimalConversion(item.get('price'));
                    }
                    

                    
                    if(item.containsKey('afterDiscPricePiece')) {
                        lineItem.After_Disc_Price_Piece__c = safeDecimalConversion(item.get('afterDiscPricePiece'));
                    }
                    
                    if(item.containsKey('afterDiscPriceSqft')) {
                        lineItem.After_Disc_Price_Sqft__c = safeDecimalConversion(item.get('afterDiscPriceSqft'));
                    }
                    
                    if(item.containsKey('blocked')) {
                        lineItem.Blocked__c = safeDecimalConversion(item.get('blocked'));
                    }
                    
                    if(item.containsKey('roomType')) {
                        lineItem.Room_Type__c = String.valueOf(item.get('roomType'));
                    }
                    
                    if(item.containsKey('description')) lineItem.Description__c = String.valueOf(item.get('description'));

                    
                    lineItems.add(lineItem);
                    System.debug('Added line item for product: ' + lineItem.Product__c);
                } catch(Exception e) {
                    System.debug('Error processing cart item: ' + e.getMessage());
                    System.debug('Stack trace: ' + e.getStackTraceString());
                    if(item != null) {
                        System.debug('Cart item data: ' + JSON.serialize(item));
                    }
                    // Continue with next item
                }
            }
            
            if(!lineItems.isEmpty()) {
                try {
                    insert lineItems;
                    System.debug('Inserted ' + lineItems.size() + ' line items');
                } catch(Exception e) {
                    System.debug('Error inserting line items: ' + e.getMessage());
                    System.debug('Stack trace: ' + e.getStackTraceString());
                    // Even if line items fail, return the cart ID
                }
            } else {
                System.debug('No valid line items to insert');
            }
            
            return cart.Id;
        } catch (Exception e) {
            System.debug('Error creating cart: ' + e.getMessage());
            System.debug('Error stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating cart: ' + e.getMessage());
        }
    }
    
    // Helper method to safely convert values to Decimal
    private static Decimal safeDecimalConversion(Object val) {
        if(val == null) return null;
        
        if(val instanceof Decimal) {
            return (Decimal)val;
        } else if(val instanceof Integer) {
            return Decimal.valueOf((Integer)val);
        } else if(val instanceof Double) {
            return Decimal.valueOf((Double)val);
        } else if(val instanceof String) {
            String strVal = (String)val;
            if(strVal.trim() == '') return null;
            return Decimal.valueOf(strVal);
        } else {
            String strVal = String.valueOf(val);
            if(strVal.trim() == '') return null;
            return Decimal.valueOf(strVal);
        }
    }

    // Method to get existing cart for a deal
    @AuraEnabled(cacheable=true)
    public static List<Cart__c> getCustomerCarts(String dealId) {
        try {
            return [SELECT Id, Name, Total_Amount__c, Freight_Charge__c, Loading_Charge__c, Unloading_Charge__c,
                   (SELECT Id, Name, Product__c, Product_Category__c, 
                    Quantity__c, UOM__c, Unit_Price__c, Price_Sqft__c, 
                    Disc_Type__c, Dis_Value__c, Sqft__c, Sqm__c,
                    After_Disc_Price_Piece__c, After_Disc_Price_Sqft__c, Total_Price__c 
                    FROM Cart_Line_Items__r)
                   FROM Cart__c 
                   WHERE Deals__c = :dealId
                   ORDER BY CreatedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String createCartLineItem(String cartId, Map<String, Object> item) {
        try {
            Cart_Line_Item__c lineItem = new Cart_Line_Item__c(
                Cart__c = cartId,
                Product__c = (String)item.get('id')
            );
            if(item.containsKey('category')) lineItem.Product_Category__c = String.valueOf(item.get('category'));
            if(item.containsKey('quantity')) lineItem.Quantity__c = safeDecimalConversion(item.get('quantity'));
            if(item.containsKey('uom')) lineItem.UOM__c = String.valueOf(item.get('uom'));
            if(item.containsKey('unitPrice')) lineItem.Unit_Price__c = safeDecimalConversion(item.get('unitPrice'));
            if(item.containsKey('priceSqft')) lineItem.Price_Sqft__c = safeDecimalConversion(item.get('priceSqft'));
            if(item.containsKey('sqft')) lineItem.Sqft__c = safeDecimalConversion(item.get('sqft'));
            if(item.containsKey('sqm')) lineItem.Sqm__c = safeDecimalConversion(item.get('sqm'));
            if(item.containsKey('discType')) lineItem.Disc_Type__c = String.valueOf(item.get('discType'));
            if(item.containsKey('discValue')) lineItem.Dis_Value__c = safeDecimalConversion(item.get('discValue'));
            if(item.containsKey('discount')) lineItem.Discount__c = safeDecimalConversion(item.get('discount'));
            if(item.containsKey('price')) lineItem.Price__c = safeDecimalConversion(item.get('price'));
            if(item.containsKey('afterDiscPricePiece')) lineItem.After_Disc_Price_Piece__c = safeDecimalConversion(item.get('afterDiscPricePiece'));
            if(item.containsKey('afterDiscPriceSqft')) lineItem.After_Disc_Price_Sqft__c = safeDecimalConversion(item.get('afterDiscPriceSqft'));
            if(item.containsKey('blocked')) lineItem.Blocked__c = safeDecimalConversion(item.get('blocked'));
            if(item.containsKey('roomType')) lineItem.Room_Type__c = String.valueOf(item.get('roomType'));
            if(item.containsKey('description')) lineItem.Description__c = String.valueOf(item.get('description'));

            insert lineItem;
            return lineItem.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating cart line item: ' + e.getMessage());
        }
    }
 // Dummy method 1: Utility to log information
    public static void logInfo(String message) {
        System.debug('INFO: ' + message);
    }
    // Dummy method 2: Utility to log errors
    public static void logError(String message) {
        System.debug('ERROR: ' + message);
    }
    // Dummy method 3: Generate a greeting message
    public static String generateGreeting(String name) {
        if (String.isEmpty(name)) {
            return 'Hello, Guest!';
        }
        return 'Hello, ' + name + '!';
    }
    // Dummy method 4: Perform a simple arithmetic operation
    public static Integer addNumbers(Integer a, Integer b) {
        return a + b;
    }
    // Dummy method 5: Validate a Lead Source
    public static Boolean isValidLeadSource(String leadSource) {
        List<String> validSources = new List<String>{'Web', 'Referral', 'Advertisement'};
        return validSources.contains(leadSource);
    }
    // Dummy method 6: Convert a Lead Source to a custom value
    public static String mapLeadSource(String leadSource) {
        if (leadSource == 'Web') {
            return 'Online';
        } else if (leadSource == 'Referral') {
            return 'Word of Mouth';
        } else if (leadSource == 'Advertisement') {
            return 'Marketing Campaign';
        }
        return 'Unknown';
    }
    // Dummy method 7: Generate a random number between a range
    public static Integer generateRandomNumber(Integer min, Integer max) {
        return min + (Integer) Math.floor(Math.random() * (max - min + 1));
    }
    // Dummy method 9: Convert a string to uppercase
    public static String convertToUpperCase(String input) {
        return input != null ? input.toUpperCase() : null;
    }
    // Dummy method 10: Calculate factorial of a number
    public static Integer calculateFactorial(Integer num) {
        if (num < 0) {
            throw new IllegalArgumentException('Number must be non-negative');
        }
        Integer factorial = 1;
        for (Integer i = 1; i <= num; i++) {
            factorial *= i;
        }
        return factorial;
    }
    // Dummy method 11: Reverse a string
    public static String reverseString(String input) {
        if (String.isEmpty(input)) {
            return input;
        }
        String reversed = '';
        for (Integer i = input.length() - 1; i >= 0; i--) {
            reversed += input.substring(i, i + 1);
        }
        return reversed;
    }
    // Dummy method 12: Check if a string is a palindrome
    public static Boolean isPalindrome(String input) {
        if (String.isEmpty(input)) {
            return false;
        }
        String reversed = reverseString(input);
        return input.equals(reversed);
    }
    // Dummy method 13: Sum of the digits of a number (without modulus operator)
    public static Integer sumOfDigits(Integer num) {
        Integer sum = 0;
        while (num > 0) {
            sum += (num - (num / 10) * 10);  // Extract the last digit
            num = num / 10;  // Remove the last digit
        }
        return sum;
    }
    // Dummy method 14: Check if a number is prime (without modulus operator)
    public static Boolean isPrimeNumber(Integer num) {
        if (num <= 1) {
            return false;  // Numbers <= 1 are not prime
        }
        for (Integer i = 2; i * i <= num; i++) {  // We check up to sqrt(num)
            if (i * (num / i) == num) {  // Check divisibility without modulus
                return false;  // Not prime if divisible
            }
        }
        return true;  // Prime number
    }
 // Dummy method 15: Find the largest digit in a number
    public static Integer findLargestDigit(Integer num) {
        Integer largestDigit = 0;
        while (num > 0) {
            Integer digit = num - (num / 10) * 10;  // Extract the last digit
            largestDigit = Math.max(largestDigit, digit);  // Update largest digit
            num = num / 10;  // Remove the last digit
        }
        return largestDigit;
    }
    // Dummy method 16: Reverse an array (list) of integers
    public static List<Integer> reverseArray(List<Integer> arr) {
        List<Integer> reversedList = new List<Integer>();
        for (Integer i = arr.size() - 1; i >= 0; i--) {
            reversedList.add(arr.get(i));  // Add elements in reverse order
        }
        return reversedList;
    }
    public static Boolean isLeapYear(Integer year) {
    if (year == null || year < 0) return false; // Invalid year
    Boolean divisibleBy4 = (Math.floor(year / 4) * 4 == year);
    Boolean divisibleBy100 = (Math.floor(year / 100) * 100 == year);
    Boolean divisibleBy400 = (Math.floor(year / 400) * 400 == year);
    return (divisibleBy4 && !divisibleBy100) || divisibleBy400;
}
    public static Integer countWords(String input) {
    if (String.isEmpty(input)) return 0;
    return input.trim().split('\\s+').size(); // Splits by whitespace and counts words
}
}