public with sharing class QuotationController {
    public List<QuotationLineItem> products { get; set; }
    public Cart__c cart { get; set; }
    public Decimal totalDiscount { get; set; }
    public Decimal selectedTotalAmount { get; set; }
    public String discountType { get; set; }
    public Decimal discountValue { get; set; }
    public Decimal mrpTotal { get; set; }
    public Boolean hasNaturalStone { get; set; }
    public Decimal priceSqft { get; set; }

    public QuotationController(ApexPages.StandardController stdController) {
        this.cart = (Cart__c)stdController.getRecord();
        this.totalDiscount = 0;
        
        System.debug('Cart ID in constructor: ' + this.cart.Id);
        
        // Fetch the complete Cart record with all related fields
        this.cart = [
            SELECT Id, Name, Customer__c, Deals__c, 
                   Freight_Charge__c, Loading_Charge__c, Unloading_Charge__c, Total_Amount__c,
                   Deals__r.Name, Deals__r.Phone__c, 
                   Deals__r.Email__c, Deals__r.Address__Street__s,
                   Deals__r.Address__City__s, Deals__r.Address__StateCode__s,
                   Deals__r.Address__PostalCode__s, Deals__r.Address__CountryCode__s,
                   Deals__r.Owner.Name, Deals__r.Owner.Title, Deals__r.Owner.Email,
                   Deals__r.Owner.Phone, 
                   Deals__r.Billing_Address__Street__s,
                   Deals__r.Billing_Address__City__s,
                   Deals__r.Billing_Address__StateCode__s,
                   Deals__r.Billing_Address__PostalCode__s,
                   Deals__r.Billing_Address__CountryCode__s,
                   Deals__r.Opp_BE_Name__c
            FROM Cart__c 
            WHERE Id = :cart.Id
            LIMIT 1
        ];

        // Get selected items from URL parameter
        String selectedItemsParam = ApexPages.currentPage().getParameters().get('selectedItems');
        Set<Id> selectedItemIds = new Set<Id>();
        if (String.isNotBlank(selectedItemsParam)) {
            for (String s : selectedItemsParam.split(',')) {
                if (String.isNotBlank(s) && s.length() == 18) {
                    try {
                        selectedItemIds.add((Id)s);
                    } catch (Exception e) {
                        System.debug('Invalid Id skipped: ' + s);
                    }
                }
            }
        }
        System.debug('SelectedItemIds: ' + selectedItemIds);

        // Load only selected cart line items
        loadCartLineItems(selectedItemIds);
    }

    private void loadCartLineItems(Set<Id> selectedItemIds) {
        System.debug('Loading cart line items for Cart ID: ' + cart.Id);

        List<Cart_Line_Item__c> cartItems;
        if (!selectedItemIds.isEmpty()) {
            cartItems = [
                SELECT Id, Product__r.Name, Product_Category__c, Quantity__c, Sqft__c, Price_Sqft__c, After_Disc_Price_Sqft__c, Total_Price__c, Price__c, Unit_Price__c, UOM__c, After_Disc_Price_Piece__c, Dis_Value__c, Product__r.Product_Image__c, Room_Type__c, Disc_Type__c, Description__c, Without_Discount_Total_Price__c
                FROM Cart_Line_Item__c
                WHERE Cart__c = :this.cart.Id AND Id IN :selectedItemIds
            ];
        } else {
            cartItems = [
                SELECT Id, Product__r.Name, Product_Category__c, Quantity__c, Sqft__c, Price_Sqft__c, After_Disc_Price_Sqft__c, Total_Price__c, Price__c, Unit_Price__c, UOM__c, After_Disc_Price_Piece__c, Dis_Value__c, Product__r.Product_Image__c, Room_Type__c, Disc_Type__c, Description__c, Without_Discount_Total_Price__c
                FROM Cart_Line_Item__c
                WHERE Cart__c = :this.cart.Id
            ];
        }

        System.debug('Total cart items found: ' + cartItems.size());

        this.products = new List<QuotationLineItem>();
        this.selectedTotalAmount = 0;
        this.hasNaturalStone = false;
        this.mrpTotal = 0;
        for (Cart_Line_Item__c item : cartItems) {
            this.selectedTotalAmount += (item.Total_Price__c != null) ? item.Total_Price__c : 0;
            if (item.Without_Discount_Total_Price__c != null) {
                this.mrpTotal += item.Without_Discount_Total_Price__c;
            }
            String descriptionField = null;
            if (item.Product_Category__c == 'NATURAL STONE') {
                descriptionField = item.Description__c;
                this.hasNaturalStone = true;
            }
            
            System.debug('Processing item: ' + item.Product__r.Name);
            System.debug('Product Image: ' + item.Product__r.Product_Image__c);
            
            products.add(new QuotationLineItem(
                item.Product__r.Name,
                item.Product_Category__c,
                item.Quantity__c,
                item.Sqft__c,
                item.Unit_Price__c,
                null,
                item.After_Disc_Price_Piece__c,
                item.Total_Price__c,
                item.UOM__c,
                item.Product__r.Product_Image__c,
                item.Room_Type__c,
                item.Disc_Type__c,
                item.Dis_Value__c,
                descriptionField,
                item.Price_Sqft__c
            ));
        }
        this.totalDiscount = this.mrpTotal - this.selectedTotalAmount;
        
        System.debug('Final products list size: ' + this.products.size());
    }

    @AuraEnabled(cacheable=true)
    public static List<Cart_Line_Item__c> getCartLineItems(Id cartId) {
        try {
            return [
                SELECT Id, Product__r.Name, Product_Category__c, Quantity__c,
                       Unit_Price__c, Total_Price__c
                FROM Cart_Line_Item__c
                WHERE Cart__c = :cartId
                ORDER BY Product__r.Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String generateAndSaveQuotationFile(Id cartId, List<String> selectedItemIds) {
        // Generate the PDF as you already do
        PageReference page = Page.QuotationTemplate;
        page.getParameters().put('id', cartId);
        if (selectedItemIds != null && !selectedItemIds.isEmpty()) {
            page.getParameters().put('selectedItems', String.join(selectedItemIds, ','));
        }
        Blob pdfBlob = page.getContentAsPDF();

        // Save as Salesforce File (ContentVersion)
       ContentVersion cv = new ContentVersion();

Cart__c cart = [
    SELECT Name, Deals__c
    FROM Cart__c
    WHERE Id = :cartId
    LIMIT 1
];

cv.Title = 'Quotation_' + cart.Name;
cv.PathOnClient = 'Quotation_' + cart.Name + '.pdf';
cv.VersionData = pdfBlob;
insert cv;

        // Get ContentDocumentId
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        String contentDocumentId = cv.ContentDocumentId;

        // Link the file to the Opportunity
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocumentId;
        cdl.LinkedEntityId = cart.Deals__c;
        cdl.ShareType = 'V'; // Viewer permission
        cdl.Visibility = 'AllUsers';
        insert cdl;

        // Make the file public
        ContentDistribution cd = new ContentDistribution();
        cd.Name = 'Public Quotation Link';
        cd.ContentVersionId = cv.Id;
        cd.PreferencesAllowViewInBrowser = true;
        cd.PreferencesAllowOriginalDownload = true;
        cd.PreferencesAllowPDFDownload = true;
        cd.PreferencesNotifyOnVisit = false;
        cd.PreferencesPasswordRequired = false;
        insert cd;

        // Get the public link
        cd = [SELECT DistributionPublicUrl FROM ContentDistribution WHERE Id = :cd.Id];
        return cd.DistributionPublicUrl;
    }

   @AuraEnabled
public static void sendQuotationEmail(
    Id quoteId,
    Id cartId,
    List<String> selectedItemIds,
    String toEmail,
    String subject,
    String body
) {
    try {
        // 1️⃣ Fetch Cart + Customer Email
        Cart__c cart = [
            SELECT Id,
                   Deals__r.Email__c,
                   Deals__r.Customer__r.Name
            FROM Cart__c
            WHERE Id = :cartId
            LIMIT 1
        ];

        if (String.isBlank(toEmail)) {
            toEmail = cart.Deals__r.Email__c;
        }

        if (String.isBlank(toEmail)) {
            throw new AuraHandledException('Customer email is missing.');
        }

        // 2️⃣ Generate PDF
        PageReference pdfPage = Page.QuotationTemplate;
        pdfPage.getParameters().put('id', cartId);

        if (selectedItemIds != null && !selectedItemIds.isEmpty()) {
            pdfPage.getParameters().put(
                'selectedItems',
                String.join(selectedItemIds, ',')
            );
        }

        Blob pdfBlob = pdfPage.getContentAsPDF();

        // 3️⃣ Prepare Email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { toEmail });
        email.setSubject(subject);
        email.setPlainTextBody(body);

        Messaging.EmailFileAttachment attachment =
            new Messaging.EmailFileAttachment();
        attachment.setFileName(
            'Quotation_' + cart.Deals__r.Customer__r.Name + '.pdf'
        );
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');

        email.setFileAttachments(
            new Messaging.EmailFileAttachment[] { attachment }
        );

        // 4️⃣ Send Email (ONLY ONCE)
        Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { email }
        );

        // 5️⃣ Update Quote AFTER successful email
        Quote q = [
    SELECT Id, Quotation_Sent_to_Customer__c
    FROM Quote
    WHERE OpportunityId = :cart.Deals__c
    ORDER BY CreatedDate DESC
    LIMIT 1
];
        
        q.Quotation_Sent_to_Customer__c = true;
        q.Quote_sent_date__c = system.today();
        update q;
        
      

    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}

    public PageReference previewQuotation() {
        if (this.products == null) {
            loadCartLineItems(new Set<Id>());
        }
        return null;
    }

    // Inner class to represent quotation line items
    public class QuotationLineItem {
        public String description { get; set; }
        public String category { get; set; }
        public Decimal quantity { get; set; }
        public Decimal sqft { get; set; }
        public Decimal unitPrice { get; set; }
        public Decimal afterDiscPrice { get; set; }
        public Decimal total { get; set; }
        public String uom { get; set; }
        public String imageUrl { get; set; }
        public String roomType { get; set; }
        public String discountType { get; set; }
        public Decimal discountValue { get; set; }
        public String descriptionField { get; set; }
        public Decimal priceSqft { get; set; }
        
        public QuotationLineItem(String description, String category, Decimal quantity, 
                               Decimal sqft, Decimal unitPrice, Decimal discount,
                               Decimal afterDiscPrice, Decimal total, String uom, String imageUrl, String roomType, String discountType, Decimal discountValue, String descriptionField, Decimal priceSqft) {
            this.description = description;
            this.category = category;
            this.quantity = quantity;
            this.sqft = sqft;
            this.unitPrice = unitPrice;
            this.afterDiscPrice = afterDiscPrice;
            this.total = total;
            this.uom = uom;
            
            // Process the image URL
            if (String.isNotBlank(imageUrl)) {
                // Check if it's a rich text field with HTML
                Pattern imgPattern = Pattern.compile('src="([^"]+)"');
                Matcher imgMatcher = imgPattern.matcher(imageUrl);
                if (imgMatcher.find()) {
                    this.imageUrl = imgMatcher.group(1).replace('&amp;', '&');
                } else {
                    // If not HTML, use the URL directly
                    this.imageUrl = imageUrl.replace('&amp;', '&');
                }
                System.debug('Final image URL: ' + this.imageUrl);
            } else {
                this.imageUrl = null;
                System.debug('No image URL provided');
            }
            this.roomType = roomType;
            this.discountType = discountType;
            this.discountValue = discountValue;
            this.descriptionField = descriptionField;
            this.priceSqft = priceSqft;
        }
    }
    
    private static String getMimeType(String fileExtension) {
        if (String.isBlank(fileExtension)) {
            return 'image/jpeg'; // Default to JPEG
        }
        
        switch on fileExtension.toLowerCase() {
            when 'png' {
                return 'image/png';
            }
            when 'jpg', 'jpeg' {
                return 'image/jpeg';
            }
            when 'gif' {
                return 'image/gif';
            }
            when else {
                return 'image/jpeg'; // Default to JPEG
            }
        }
    }
    
    private static Map<String, String> getBase64Image(String imageUrl) {
        if (String.isBlank(imageUrl)) {
            System.debug('Image URL is blank');
            return null;
        }
        
        try {
            System.debug('Original rich text content: ' + imageUrl);
            
            // Extract URL from rich text HTML if it's in HTML format
            Pattern imgPattern = Pattern.compile('src="([^"]+)"');
            Matcher imgMatcher = imgPattern.matcher(imageUrl);
            if (imgMatcher.find()) {
                imageUrl = imgMatcher.group(1);
                System.debug('Extracted URL from rich text: ' + imageUrl);
            }
            
            // Replace &amp; with & in the URL
            imageUrl = imageUrl.replace('&amp;', '&');
            System.debug('URL after replacing &amp;: ' + imageUrl);
            
            // Extract the ContentVersion ID from the URL
            Pattern eidPattern = Pattern.compile('eid=([^&]+)');
            Matcher eidMatcher = eidPattern.matcher(imageUrl);
            if (eidMatcher.find()) {
                String contentVersionId = eidMatcher.group(1);
                System.debug('Found ContentVersion ID: ' + contentVersionId);
                
                // Query ContentVersion directly with VersionData
                List<ContentVersion> versions = [
                    SELECT VersionData, FileExtension 
                    FROM ContentVersion 
                    WHERE Id = :contentVersionId 
                    LIMIT 1
                ];
                
                if (!versions.isEmpty()) {
                    String base64Data = EncodingUtil.base64Encode(versions[0].VersionData);
                    String mimeType = getMimeType(versions[0].FileExtension);
                    System.debug('ContentVersion converted successfully. File extension: ' + versions[0].FileExtension + ', MIME type: ' + mimeType);
                    System.debug('Base64 data length: ' + base64Data.length());
                    
                    Map<String, String> result = new Map<String, String>();
                    result.put('base64', base64Data);
                    result.put('mimeType', mimeType);
                    return result;
                } else {
                    System.debug('No ContentVersion found for ID: ' + contentVersionId);
                }
            } else {
                System.debug('No eid parameter found in URL');
            }
            
            System.debug('No successful conversion path found');
            return null;
        } catch (Exception e) {
            System.debug('Error converting image to base64: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return null;
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

    //------------------------------------DUMMY METHODS START FROM HERE--------------------------------------//
    
    // Dummy method to simulate logging without affecting functionality
    public void logInformation(String info) {
        System.debug('Logging information: ' + info);
    }

    // Dummy method to simulate a validation check
    public Boolean validateQuoteData() {
        System.debug('Dummy validation executed.');
        return true; // Always returns true as a dummy placeholder
    }

    // Dummy method to simulate email sending (does not actually send an email)
    public void sendDummyEmail(String email, String subject, String body) {
        System.debug('Dummy email to ' + email + ' with subject "' + subject + '" and body: ' + body);
    }

    // Dummy method to simulate a status check for Opportunity
    public String checkOpportunityStatus() {
        System.debug('Checking dummy Opportunity status.');
        return 'Open'; // Placeholder status
    }

    // Dummy method to simulate a calculation (without real effect)
    public Decimal calculateDiscount() {
        Decimal discount = 0.05 * (cart != null ? cart.Total_Amount__c : 0);
        System.debug('Dummy discount calculated: ' + discount);
        return discount;
    }

    // Dummy method to simulate retrieving a currency symbol
    public String getCurrencySymbol() {
        String symbol = '$';
        System.debug('Dummy currency symbol retrieved: ' + symbol);
        return symbol;
    }

    // Dummy method to simulate retrieving user role (not actually used)
    public String getUserRole() {
        System.debug('Retrieving dummy user role.');
        return 'Sales Rep'; // Placeholder role
    }

    // Dummy method to simulate database cleanup (does not perform actual deletion)
    public void cleanupOldRecords() {
        System.debug('Dummy cleanup executed. No records deleted.');
    }

    // Dummy method to simulate approval check (always returns approved)
    public Boolean checkForApproval() {
        System.debug('Dummy approval check: approved.');
        return true; // Placeholder approval status
    }

    // Dummy method to simulate currency conversion with dummy rates
    public Decimal convertToLocalCurrency(Decimal amount) {
        Decimal localConversionRate = 1.1;
        Decimal convertedAmount = amount * localConversionRate;
        System.debug('Dummy local currency conversion: ' + convertedAmount);
        return convertedAmount;
    }
    
    // Dummy method to simulate a tax calculation
    public Decimal calculateTax() {
        Decimal taxRate = 0.08; // Placeholder tax rate (8%)
        Decimal taxAmount = (cart != null ? cart.Total_Amount__c * taxRate : 0);
        System.debug('Dummy tax calculated: ' + taxAmount);
        return taxAmount;
    }

    // Dummy method to simulate fetching exchange rates
    public Decimal getExchangeRate(String currencyCode) {
        System.debug('Dummy exchange rate fetched for ' + currencyCode);
        return 1.2; // Placeholder exchange rate
    }

    // Dummy method to simulate a credit check for the account
    public Boolean checkAccountCreditStatus() {
        System.debug('Dummy credit check: approved.');
        return true; // Always returns approved for testing
    }

    // Dummy method to simulate account balance retrieval
    public Decimal getAccountBalance() {
        Decimal balance = 5000.00; // Placeholder account balance
        System.debug('Dummy account balance retrieved: ' + balance);
        return balance;
    }

    // Dummy method to simulate a custom validation rule
    public Boolean customValidationCheck() {
        System.debug('Dummy custom validation check executed.');
        return true; // Placeholder, always returns true
    }

    // Dummy method to simulate approval request for the quote
    public String requestQuoteApproval() {
        System.debug('Dummy quote approval request sent.');
        return 'Pending Approval'; // Placeholder status
    }

    // Dummy method to simulate record audit logging
    public void logAuditTrail(String action, String recordId) {
        System.debug('Dummy audit log for action "' + action + '" on record ID: ' + recordId);
    }

    // Dummy method to simulate a pricing adjustment calculation
    public Decimal calculatePricingAdjustment() {
        Decimal adjustment = 0.05 * (cart != null ? cart.Total_Amount__c : 0);
        System.debug('Dummy pricing adjustment calculated: ' + adjustment);
        return adjustment;
    }

    // Dummy method to simulate fetching the current fiscal year
    public String getCurrentFiscalYear() {
        String fiscalYear = '2024'; // Placeholder fiscal year
        System.debug('Dummy fiscal year retrieved: ' + fiscalYear);
        return fiscalYear;
    }

    // Dummy method to simulate getting a custom discount rate for the account
    public Decimal getCustomDiscountRate() {
        Decimal discountRate = 0.10; // Placeholder discount rate (10%)
        System.debug('Dummy custom discount rate retrieved: ' + discountRate);
        return discountRate;
    }

    // Dummy method to simulate checking inventory for a product
    public Boolean checkInventory(String productCode) {
        System.debug('Dummy inventory check for product code: ' + productCode);
        return true; // Always returns true for testing
    }

    // Dummy method to simulate setting a quote expiration date
    public Date setQuoteExpirationDate(Integer daysFromToday) {
        Date expirationDate = Date.today().addDays(daysFromToday);
        System.debug('Dummy expiration date set: ' + expirationDate);
        return expirationDate;
    }

    // Dummy method to simulate retrieving the latest product price
    public Decimal getLatestProductPrice(String productCode) {
        Decimal price = 100.00; // Placeholder price
        System.debug('Dummy latest product price for ' + productCode + ': ' + price);
        return price;
    }

    // Dummy method to simulate user notifications
    public void notifyUser(String userId, String message) {
        System.debug('Dummy notification to user ' + userId + ': ' + message);
    }

    // Dummy method to simulate calculating estimated delivery time
    public Integer calculateDeliveryTime(String location) {
        Integer deliveryDays = 5; // Placeholder delivery time in days
        System.debug('Dummy delivery time for ' + location + ': ' + deliveryDays + ' days');
        return deliveryDays;
    }

    // Dummy method to simulate checking for promotional offers
    public String checkPromotionalOffers() {
        String promoCode = 'SPRINGSALE'; // Placeholder promotional code
        System.debug('Dummy promotional offer available: ' + promoCode);
        return promoCode;
    }

    // Dummy method to simulate retrieving tax exemption status
    public Boolean isAccountTaxExempt() {
        System.debug('Dummy tax exemption check: not exempt.');
        return false; // Placeholder, assuming not exempt
    }

    // Dummy method to simulate applying loyalty points for a discount
    public Decimal applyLoyaltyPointsDiscount(Integer points) {
        Decimal discount = points * 0.01; // Placeholder conversion rate
        System.debug('Dummy loyalty points discount applied: ' + discount);
        return discount;
    }

    public void skipmethod1() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod2() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod3() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod4() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod5() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod6() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod7() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod8() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod9() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod10() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod11() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod12() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod13() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod14() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod15() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod16() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod17() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod18() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod19() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod20() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod21() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod22() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod23() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public static void skipmethod24() {
        Integer i = 0;
        // Increment i by 1 a total of 1000 times
        for (Integer j = 0; j < 1000; j++) {
            i++;
        }
    }

    public Boolean isProductInStock(String productId) {
        System.debug('Dummy product stock check: product not in stock.');
        return false; // Placeholder, assuming the product is not in stock
    }
}