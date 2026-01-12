import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateQuotation from '@salesforce/apex/QuotationController.generateQuotation';
import sendQuotationEmail from '@salesforce/apex/QuotationController.sendQuotationEmail';

export default class DealQuotation extends LightningElement {
    @api recordId; // Deal/Opportunity Id
    @track isLoading = false;
    @track isLoadingPdf = false;
    @track isSendingEmail = false;
    @track showQuotationModal = false;
    @track showEmailModal = false;
    @track quotationUrl;
    @track toEmail = '';
    @track emailSubject = 'Quotation from Le Marble Gallery';
    @track emailBody = 'Please find attached the quotation for your reference.';
    @track quotationBlob;

    async handleCreateQuotation() {
        this.isLoading = true;
        try {
            // Get the Visualforce domain
            const vfBaseURL = window.location.origin.replace('lightning.force.com', '--c.visualforce.com');
            // Construct the correct URL
            const url = `${vfBaseURL}/apex/QuotationTemplate?id=${this.recordId}`;
            window.open(url, '_blank');
        } catch (error) {
            this.showToast('Error', error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getBaseUrl() {
        let baseUrl = window.location.origin;
        if (baseUrl.indexOf('.lightning.force.com') > -1) {
            baseUrl = baseUrl.substring(0, baseUrl.indexOf('.lightning.force.com'));
        }
        return baseUrl;
    }

    handleIframeLoad() {
        this.isLoadingPdf = false;
    }

    closeQuotationModal() {
        this.showQuotationModal = false;
    }

    handleDownload() {
        const link = document.createElement('a');
        link.href = this.quotationUrl;
        link.download = 'Quotation.pdf';
        link.click();
    }

    handleSendEmail() {
        this.showEmailModal = true;
    }

    closeEmailModal() {
        this.showEmailModal = false;
    }

    handleToEmailChange(event) {
        this.toEmail = event.target.value;
    }

    handleSubjectChange(event) {
        this.emailSubject = event.target.value;
    }

    handleBodyChange(event) {
        this.emailBody = event.target.value;
    }

    get sendButtonDisabled() {
        return !this.toEmail || this.isSendingEmail;
    }

    async sendEmail() {
        try {
            this.isSendingEmail = true;
            await sendQuotationEmail({
                dealId: this.recordId,
                toEmail: this.toEmail,
                subject: this.emailSubject,
                body: this.emailBody,
                quotationBlob: this.quotationBlob
            });
            this.showToast('Success', 'Quotation sent successfully', 'success');
            this.closeEmailModal();
            this.closeQuotationModal();
        } catch (error) {
            this.showToast('Error', 'Failed to send email: ' + error.message, 'error');
        } finally {
            this.isSendingEmail = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            }),
        );
    }
}