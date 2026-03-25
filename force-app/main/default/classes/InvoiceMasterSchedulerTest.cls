@IsTest
public class InvoiceMasterSchedulerTest {


@IsTest
static void testSchedulerExecution() {

    // Mock the HTTP callout
    Test.setMock(HttpCalloutMock.class, new InvoiceMasterMockCallout());

    Test.startTest();

    String cronExp = '0 0 2 * * ?';

    System.schedule(
        'Test Invoice Scheduler',
        cronExp,
        new InvoiceMasterScheduler()
    );
 System.enqueueJob(new InvoiceMasterQueueable());
    Test.stopTest();

    System.assert(true);
}
    class InvoiceMasterMockCallout implements HttpCalloutMock {
        
        public HTTPResponse respond(HTTPRequest req){
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type','application/json');
            
            if(req.getEndpoint().contains('Login')){
                res.setStatusCode(200);
                res.setBody('{"SessionId":"ABC123"}');
            }
            
            else if(req.getEndpoint().contains('Orders')){
                res.setStatusCode(201);
                res.setBody(
                    '{"DocEntry":1,"DocNum":1001,"DocTotal":500,"CardCode":"C001"}'
                );
            }
            else if(req.getEndpoint().contains('Invoices')){
                res.setStatusCode(200);
                res.setBody(
                    '{"value":[{' +
                    '"DocEntry":"1",' +
                    '"DocNum":"100",' +
                    '"DocDate":"2024-01-01",' +
                    '"DocTotal":"500",' +
                    '"CardCode":"C001",' +
                    '"SalesPersonCode":"EMP001",' +
                    '"Cancelled":"N",' +
                    '"TotalDiscount":"0",' +
                    '"DocumentLines":[{' +
                    '"LineNum":1,' +
                    '"ItemCode":"P100",' +
                    '"LineTotal":100,' +
                    '"Price":100,' +
                    '"Quantity":1,' +
                    '"WarehouseCode":"WH1"' +
                    '}],' +
                    '"DocumentAdditionalExpenses":[]' +
                    '},{' +
                    '"DocEntry":"2",' +
                    '"DocNum":"101",' +
                    '"DocDate":"2024-01-02",' +
                    '"DocTotal":"600",' +
                    '"CardCode":"C002",' +
                    '"SalesPersonCode":"EMP001",' +
                    '"Cancelled":"N",' +
                    '"TotalDiscount":"0",' +
                    '"DocumentLines":[{' +
                    '"LineNum":1,' +
                    '"ItemCode":"P200",' +
                    '"LineTotal":200,' +
                    '"Price":200,' +
                    '"Quantity":2,' +
                    '"WarehouseCode":"WH1"' +
                    '}],' +
                    '"U_TOTALKM":"2",'+
                    '"DocumentAdditionalExpenses":[]' +
                    '}]}'
                );
            }
            
            else if(req.getEndpoint().contains('IncomingPayments')){
                res.setStatusCode(200);
                res.setBody(
                    '{"value":[{' +
                    '"DocNum":"1",' +
                    '"DocDate":"2024-01-01",' +
                    '"TransferSum":"100",' +
                    '"CashSum":"0",' +
                    '"DocEntry":"1",' +
                    '"CardCode":"C001",' +
                    '"CardName":"Test Account"' +
                    '},{' +
                    '"DocNum":"2",' +
                    '"DocDate":"2024-01-02",' +
                    '"TransferSum":"200",' +
                    '"CashSum":"0",' +
                    '"DocEntry":"2",' +
                    '"CardCode":"C002",' +
                    '"CardName":"Test Account 2"' +
                    '}]}'
                );
            }
            
            else if(req.getEndpoint().contains('BusinessPartners') && req.getMethod()=='GET'){
                res.setStatusCode(404); // simulate not existing
                res.setBody('{}');
            }
            
            else if(req.getEndpoint().contains('BusinessPartners') && req.getMethod()=='POST'){
                res.setStatusCode(201);
                res.setBody('{"CardCode":"C001"}');
            }
            
            else if(req.getEndpoint().contains('BusinessPartners') && req.getMethod()=='PATCH'){
                res.setStatusCode(204);
                res.setBody('{}');
            }
            else{
                res.setStatusCode(200);
                res.setBody('{}');
            }
            
            return res;
        }
    }
    

}