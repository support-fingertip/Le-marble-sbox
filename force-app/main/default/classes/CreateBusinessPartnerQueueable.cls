public class CreateBusinessPartnerQueueable  implements Queueable, Database.AllowsCallouts {

    private Id dealId;

    public CreateBusinessPartnerQueueable(Id dealId) {
        this.dealId = dealId;
    }

    public void execute(QueueableContext qc) {
        sapIntegration.createBusinessPartner(dealId);
    }
}