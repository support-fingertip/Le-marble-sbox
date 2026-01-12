import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import generateAndSaveQuotationFile from '@salesforce/apex/QuotePdfController.generateAndSaveQuotationFile';
import sendQuotationEmail from '@salesforce/apex/QuotePdfController.sendQuotationEmail';
import getCartLineItems from '@salesforce/apex/QuotePdfController.getCartLineItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import EMAIL_FIELD from '@salesforce/schema/Quote.Email';
import EXPIRATION_FIELD from '@salesforce/schema/Quote.ExpirationDate';

export default class QuotationButton extends NavigationMixin(LightningElement) {
    quoteEmail;
    expirationDate;
    @api recordId;
    showSelectionModal = false;
    showPdfModal = false;
    isLoading = false;
    isSendingEmail = false;
    downloadUrl;
    cartLineItems = [];
    selectedItems = [];
    columns = [
        { label: 'Product Name', fieldName: 'productName', type: 'text' },
        { label: 'Category', fieldName: 'category', type: 'text' },
        { label: 'Quantity', fieldName: 'quantity', type: 'number' },
        { label: 'Unit Price', fieldName: 'unitPrice', type: 'currency' },
        { label: 'Total Price', fieldName: 'totalPrice', type: 'currency' }
    ];

    get isMobile() {
        return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    }

    @wire(getCartLineItems, { cartId: '$recordId' })
    wiredCartLineItems({ error, data }) {
        if (data) {
            this.cartLineItems = data.map(item => ({
                id: item.Id,
                productName: item.Product2.Name,
                category: item.Product_Category__c,
                quantity: item.Quantity,
                unitPrice: item.UnitPrice,
                totalPrice: item.TotalPrice,
                selected: false
            }));
        }
    }

    // 🔹 ADD THIS WIRE ANYWHERE INSIDE THE CLASS (best: after the first wire)
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [EMAIL_FIELD, EXPIRATION_FIELD]
    })
    wiredQuote({ data, error }) {
        if (data) {
            this.quoteEmail = data.fields.Email.value;
            this.expirationDate = data.fields.ExpirationDate.value;
        } else if (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load quote details',
                    variant: 'error'
                })
            );
        }
    }

    // 🔹 rest of your methods
    handleOpenQuotation() {
        this.showSelectionModal = true;
    }


    handleSelectionClose() {
        this.showSelectionModal = false;
        this.selectedItems = [];
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedItems = selectedRows.map(row => row.id);
    }

    async handleProceed() {
        if (this.selectedItems.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Warning',
                message: 'Please select at least one item',
                variant: 'warning'
            }));
            return;
        }
        this.showSelectionModal = false;
        this.showPdfModal = true;
        await this.loadQuotation();
    }

    async loadQuotation() {
        try {
            this.isLoading = true;
            this.downloadUrl = await generateAndSaveQuotationFile({
                cartId: this.recordId,
                selectedItemIds: this.selectedItems
            });
        } catch (error) {
            let message = error && error.body && error.body.message
                ? error.body.message
                : (error.message || JSON.stringify(error));
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to load quotation: ' + message,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    handleDownload() {
        if (this.downloadUrl) {
            window.open(this.downloadUrl, '_blank');
        }
    }

    handleViewPdf() {
      const url = `/apex/StandardQuote?id=${this.recordId}&selectedItems=${this.selectedItems.join(',')}`;

        window.open(url, '_blank');
    }

    handleClose() {
        this.showPdfModal = false;
    }

   async handleSendEmail() {


    if (!this.quoteEmail) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Email is required before sending the quotation.',
                variant: 'error'
            })
        );
        return;
    }

    // 2️⃣ Expiration Date validation
    if (!this.expirationDate) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Expiration Date is required before sending the quotation.',
                variant: 'error'
            })
        );
        return;
    }

    // 3️⃣ Future date validation
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const expDate = new Date(this.expirationDate);

    if (expDate <= today) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Expiration Date must be a future date.',
                variant: 'error'
            })
        );
        return;
    }

    // 4️⃣ Send email ONLY if valid
    try {
        this.isSendingEmail = true;

        await sendQuotationEmail({
            cartId: this.recordId,
            selectedItemIds: this.selectedItems,
            toEmail: this.quoteEmail, // ✅ FIXED
            subject: 'Quotation from Le Marbles',
            body: 'Please find attached the quotation for your reference.',
            quotationBlob: null
        });

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Quotation sent successfully',
                variant: 'success'
            })
        );

        this.handleClose();

    } catch (error) {
        let message =
            error?.body?.message ||
            error?.message ||
            'Failed to send quotation';

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error'
            })
        );
    } finally {
        this.isSendingEmail = false;
    }
}

    get pdfIframeUrl() {
       return `/apex/StandardQuote?id=${this.recordId}&selectedItems=${this.selectedItems.join(',')}`;


    }
}