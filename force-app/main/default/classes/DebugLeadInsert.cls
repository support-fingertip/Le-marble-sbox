@isTest
private class DebugLeadInsert {
    @isTest static void tryInsertLead() {
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Debug',
            Company = 'Debug Co',
            Email = 'debug@example.com'
            // Add more fields here if needed
        );
        try {
            insert l;
            System.debug('Lead insert succeeded: ' + l.Id);
            System.assert(true, 'Lead inserted successfully');
        } catch (Exception e) {
            System.debug('Lead insert failed: ' + e.getMessage());
            System.assert(false, e.getMessage());
        }
    }
}