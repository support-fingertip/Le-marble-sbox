public class LeadThankYouEmailHelper {

    @future
    public static void sendThankYouEmail(List<Id> leadIds) {

        List<Lead> leads = [
            SELECT Id, FirstName, Email
            FROM Lead
            WHERE Id IN :leadIds
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Lead l : leads) {
            if (l.Email == null) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            mail.setToAddresses(new List<String>{ l.Email });
            mail.setSubject('Thank you for contacting us!');

            String body =
                'Hello ' + (l.FirstName != null ? l.FirstName : 'Customer') + ',<br/><br/>' +
                'Thank you for contacting us.<br/>' +
                'We have received your lead details and our team will contact you shortly.<br/><br/>' +
                'Regards,<br/>' +
                'Le Marble';

            mail.setHtmlBody(body);
            mail.setSaveAsActivity(true);

            emails.add(mail);
        }

        Messaging.sendEmail(emails);
    }
}