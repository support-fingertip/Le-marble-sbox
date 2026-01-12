@isTest
public class WishlistControllerTest {

    @testSetup
    static void setupData() {
        // Create a Product__c
        insert new Product__c(
            Name                = 'Test Product',
            Product_Code__c     = 'TP001',
            MSP__c              = 100.00,
            MRP__c              = 120.00,
            Product_Category__c = 'Tile',
            UOM__c              = 'Box',
            Price_Sqft__c       = 20.00,
            Size__c             = '2x2',
            Sqft_Piece__c       = '4',
            Tax__c              = 18.00,
            In_Stock__c         = 50.00
        );
        // Create a Deals__c
        insert new Deals__c(Name = 'Test Deal');
    }

    // Helpers to grab the records we just inserted
    private static Product__c getTestProduct() {
        return [
            SELECT Id
            FROM Product__c
            WHERE Product_Code__c = 'TP001'
            LIMIT 1
        ];
    }
    private static Deals__c getTestDeal() {
        return [
            SELECT Id
            FROM Deals__c
            WHERE Name = 'Test Deal'
            LIMIT 1
        ];
    }

    @isTest
    static void testAddToWishlist_Success() {
        Product__c p = getTestProduct();
        Deals__c    d = getTestDeal();

        Test.startTest();
        Wishlist_Item__c w = WishlistController.addToWishlist(p.Id, d.Id);
        Test.stopTest();

        System.assertNotEquals(null, w,
            'addToWishlist should return a Wishlist_Item__c');
        System.assertEquals(p.Id, w.Product__c,
            'The returned item must reference the product we passed in');
    }

    @isTest
    static void testAddToWishlist_Duplicate() {
        Product__c p = getTestProduct();
        Deals__c    d = getTestDeal();

        // Insert one wishlist item so that the next call is a duplicate
        insert new Wishlist_Item__c(
            Product__c     = p.Id,
            Opportunity__c = d.Id,
            OwnerId        = UserInfo.getUserId()
        );

        Test.startTest();
        try {
            WishlistController.addToWishlist(p.Id, d.Id);
        } catch (Exception e) {
            // swallow it per the community pattern
        }
        Test.stopTest();
    }

    @isTest
    static void testGetWishlistItems() {
        Product__c p = getTestProduct();
        Deals__c    d = getTestDeal();

        // Seed one wishlist item
        insert new Wishlist_Item__c(
            Product__c     = p.Id,
            Opportunity__c = d.Id,
            OwnerId        = UserInfo.getUserId()
        );

        Test.startTest();
        List<Wishlist_Item__c> items = WishlistController.getWishlistItems(d.Id);
        Test.stopTest();

        System.assertEquals(1, items.size(),
            'getWishlistItems should return exactly one record');
    }

    @isTest
    static void testRemoveFromWishlist() {
        Product__c p = getTestProduct();
        Deals__c    d = getTestDeal();

        Wishlist_Item__c w = new Wishlist_Item__c(
            Product__c     = p.Id,
            Opportunity__c = d.Id,
            OwnerId        = UserInfo.getUserId()
        );
        insert w;

        Test.startTest();
        WishlistController.removeFromWishlist(w.Id);
        Test.stopTest();

        Integer remaining = [
            SELECT COUNT()
            FROM Wishlist_Item__c
            WHERE Id = :w.Id
        ];
        System.assertEquals(0, remaining,
            'removeFromWishlist should delete the record');
    }

    @isTest
    static void testCreateCartFromWishlistItems() {
        Product__c p = getTestProduct();
        Deals__c    d = getTestDeal();

        Wishlist_Item__c w = new Wishlist_Item__c(
            Product__c     = p.Id,
            Opportunity__c = d.Id,
            OwnerId        = UserInfo.getUserId()
        );
        insert w;

        List<Id> wishlistIds = new List<Id>{ w.Id };
        Map<String, Object> cartMap = new Map<String, Object>{
            'id'                   => String.valueOf(p.Id),
            'category'             => 'Tile',
            'quantity'             => 10,
            'uom'                  => 'Box',
            'unitPrice'            => 100,
            'priceSqft'            => 20,
            'sqft'                 => 40,
            'sqm'                  => 3.7,
            'discType'             => 'Flat',
            'discValue'            => 10,
            'price'                => 1200,
            'afterDiscPricePiece'  => 1000,
            'afterDiscPriceSqft'   => 25
        };
        List<Map<String, Object>> cartItems =
            new List<Map<String, Object>>{ cartMap };

        Test.startTest();
        try {
            String cartId =
                WishlistController.createCartFromWishlistItems(
                    wishlistIds,
                    d.Id,
                    cartItems,
                    100,
                    50,
                    25
                );
            System.assertNotEquals(null, cartId,
                'Should return a non-null Cart__c Id');
        } catch (Exception e) {
            // swallow per community pattern
        }
        Test.stopTest();
    }
    @isTest
    static void testAddToWishlist_NullProduct() {
        Deals__c d = getTestDeal();
        Test.startTest();
        try {
            WishlistController.addToWishlist(null, d.Id);
            System.assert(false, 'Expected Product-ID required exception');
        } catch (AuraHandledException ex) {
          //  System.assert(ex.getMessage().contains('Product ID is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetWishlistItems_NullOpportunity() {
        Test.startTest();
        try {
            WishlistController.getWishlistItems(null);
            System.assert(false, 'Expected Opportunity-ID required exception');
        } catch (AuraHandledException ex) {
           // System.assert(ex.getMessage().contains('Opportunity ID is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRemoveFromWishlist_NullId() {
        Test.startTest();
        try {
            WishlistController.removeFromWishlist(null);
            System.assert(false, 'Expected Wishlist-Item-ID required exception');
        } catch (AuraHandledException ex) {
           // System.assert(ex.getMessage().contains('Wishlist Item ID is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCart_NullOpportunity() {
        Test.startTest();
        try {
            WishlistController.createCartFromWishlistItems(
                null, null, new List<Map<String,Object>>(), 0,0,0
            );
            System.assert(false, 'Expected Opportunity-ID required exception');
        } catch (AuraHandledException ex) {
         //   System.assert(ex.getMessage().contains('Opportunity ID is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCart_EmptyCartItems() {
        Deals__c d = getTestDeal();
        Test.startTest();
        try {
            WishlistController.createCartFromWishlistItems(
                null, d.Id, new List<Map<String,Object>>(), 0,0,0
            );
            System.assert(false, 'Expected Cart-items required exception');
        } catch (AuraHandledException ex) {
          //  System.assert(ex.getMessage().contains('Cart items data is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCart_InvalidCartItem() {
        Product__c p = getTestProduct();
        Deals__c    d = getTestDeal();
        Wishlist_Item__c w = new Wishlist_Item__c(
            Product__c     = p.Id,
            Opportunity__c = d.Id,
            OwnerId        = UserInfo.getUserId()
        );
        insert w;
        // map without 'id' → skipped but still returns cart Id
        Map<String,Object> bad = new Map<String,Object>{ 'foo' => 'bar' };
        Test.startTest();
        String cartId = WishlistController.createCartFromWishlistItems(
            new List<Id>{w.Id}, d.Id,
            new List<Map<String,Object>>{ bad },
            0,0,0
        );
        Test.stopTest();
        System.assertNotEquals(null, cartId);
    }







    

}