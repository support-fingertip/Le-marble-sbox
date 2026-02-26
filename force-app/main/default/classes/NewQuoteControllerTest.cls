@IsTest
private class NewQuoteControllerTest {
    @IsTest
    static void testUtilityMethods() {
        Test.startTest();
        String greetingGuest = NewQuoteController.generateGreeting('');
        String greetingUser = NewQuoteController.generateGreeting('Alex');
        Integer sum = NewQuoteController.addNumbers(2, 3);
        Boolean validLeadSource = NewQuoteController.isValidLeadSource('Web');
        String mappedSource = NewQuoteController.mapLeadSource('Referral');
        Integer randomVal = NewQuoteController.generateRandomNumber(1, 3);
        String upper = NewQuoteController.convertToUpperCase('tile');
        Integer factorial = NewQuoteController.calculateFactorial(5);
        String reversed = NewQuoteController.reverseString('abc');
        Boolean palindrome = NewQuoteController.isPalindrome('level');
        Integer digitSum = NewQuoteController.sumOfDigits(123);
        Boolean prime = NewQuoteController.isPrimeNumber(11);
        Integer largestDigit = NewQuoteController.findLargestDigit(784);
        List<Integer> reversedArray = NewQuoteController.reverseArray(new List<Integer>{1, 2, 3});
        Boolean leap = NewQuoteController.isLeapYear(2024);
        Integer wordCount = NewQuoteController.countWords('one two three');
        Test.stopTest();

        System.assertEquals('Hello, Guest!', greetingGuest);
        System.assertEquals('Hello, Alex!', greetingUser);
        System.assertEquals(5, sum);
        System.assertEquals(true, validLeadSource);
        System.assertEquals('Word of Mouth', mappedSource);
        System.assert(randomVal >= 1 && randomVal <= 3);
        System.assertEquals('TILE', upper);
        System.assertEquals(120, factorial);
        System.assertEquals('cba', reversed);
        System.assertEquals(true, palindrome);
        System.assertEquals(6, digitSum);
        System.assertEquals(true, prime);
        System.assertEquals(8, largestDigit);
        System.assertEquals(3, reversedArray.size());
        System.assertEquals(3, reversedArray[0]);
        System.assertEquals(true, leap);
        System.assertEquals(3, wordCount);
    }

    @IsTest
    static void testPicklistAndPricebookMethods() {
        Test.startTest();
        List<String> categories = NewQuoteController.getProductCategories();
        List<Map<String, String>> areaPicklist = NewQuoteController.getAreaPicklistValues();
        List<String> priceNames = NewQuoteController.getPriceNames();
        Test.stopTest();

        System.assertNotEquals(null, categories);
        System.assertNotEquals(null, areaPicklist);
        System.assertNotEquals(null, priceNames);
    }
}