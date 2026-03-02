@IsTest
public class LeadTriggerTest {

    private static Lead createLead(Integer num) {

        // Set country explicitly
        String countryValue = 'USA'; // must match picklist dependency

        // Get country code allowed for that country
        String validCode = null;

        Schema.DescribeFieldResult d =
            Lead.Country_Code__c.getDescribe();

        for (Schema.PicklistEntry p : d.getPicklistValues()) {

            // Check controlling field values
            if (p.isActive()) {
                validCode = p.getValue();
                break;
            }
        }

        return new Lead(
            LastName = 'Test Lead ' + num,
            Company = 'Test Company',
            Status = 'Open - Not Contacted',

            // IMPORTANT
            Country__c = countryValue,
            Country = countryValue,

            Country_Code__c = validCode,

            Email = 'test' + num + System.currentTimeMillis() + '@email.com',
            Phone = '9876543210'
        );
    }

    @IsTest
    static void testInsertTrigger() {

        Lead l = createLead(1);

        Test.startTest();
        insert l;
        Test.stopTest();

        System.assertNotEquals(null, l.Id);
    }

    @IsTest
    static void testUpdateTrigger() {

        Lead l = createLead(2);
        insert l;

        l.Company = 'Updated Company';

        Test.startTest();
        update l;
        Test.stopTest();

        System.assertEquals(
            'Updated Company',
            [SELECT Company FROM Lead WHERE Id = :l.Id].Company
        );
    }

    @IsTest
    static void testBulkInsert() {

        List<Lead> leads = new List<Lead>();

        for (Integer i = 0; i < 5; i++) {
            leads.add(createLead(i));
        }

        Test.startTest();
        insert leads;
        Test.stopTest();

        System.assertEquals(5, leads.size());
    }
}