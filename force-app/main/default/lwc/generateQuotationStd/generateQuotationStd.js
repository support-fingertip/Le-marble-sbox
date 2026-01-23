import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import generateAndSaveQuotationFile from '@salesforce/apex/QuotationController.generateAndSaveQuotationFile';
import sendQuotationEmail from '@salesforce/apex/QuotationController.sendQuotationEmail';
import getCartLineItems from '@salesforce/apex/QuotationController.getCartLineItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { getRecordNotifyChange } from 'lightning/uiRecordApi';

import { getRecord } from 'lightning/uiRecordApi';

const QUOTE_FIELDS = [
    'Quote.Quotation_Sent_to_Customer__c'
];

export default class QuotationButton extends NavigationMixin(LightningElement) {


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

    @wire(getRecord, { recordId: '$recordId', fields: QUOTE_FIELDS })
    quoteRecord;

    @wire(getCartLineItems, { cartId: '$recordId'  })
    wiredCartLineItems({ error, data }) {
        if (data) {
            this.cartLineItems = data.map(item => ({
                id: item.Id,
                productName: item.Product__r.Name,
                category: item.Product_Category__c,
                quantity: item.Quantity__c,
                unitPrice: item.Unit_Price__c,
                totalPrice: item.Total_Price__c,
                selected: false
            }));
        } else if (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Error loading cart items: ' + error.message,
                variant: 'error'
            }));
        }
    }

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
        const url = `/apex/QuotePdfController?id=${this.recordId}&selectedItems=${this.selectedItems.join(',')}`;
        window.open(url, '_blank');
    }

    handleClose() {
        this.showPdfModal = false;
    }

    async handleSendEmail() {
        try {
            this.isSendingEmail = true;



        

            await sendQuotationEmail({
            
                cartId: this.recordId,        
                selectedItemIds: this.selectedItems,
                toEmail: null,
                subject: 'Quotation from Le Marbles',
                body: 'Please find attached the quotation for your reference.'
            
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Quotation sent successfully',
                variant: 'success'
            }));
            this.showPdfModal = false;

                // refresh the Quote record so checkbox updates
            getRecordNotifyChange([{ recordId: this.recordId }]);
        } catch (error) {
            let message = error && error.body && error.body.message
                ? error.body.message
                : (error.message || JSON.stringify(error));
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to send quotation: ' + message,
                variant: 'error'
            }));
        } finally {
            this.isSendingEmail = false;
        }
    }

    get pdfIframeUrl() {
        return `/apex/StandardQuote?id=${this.recordId}&selectedItems=${this.selectedItems.join(',')}`;
    }
}