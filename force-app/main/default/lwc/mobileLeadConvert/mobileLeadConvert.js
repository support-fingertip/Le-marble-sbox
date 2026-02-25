import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getConversionContext from '@salesforce/apex/MobileLeadConversionController.getConversionContext';
import searchAccounts from '@salesforce/apex/MobileLeadConversionController.searchAccounts';
import searchContacts from '@salesforce/apex/MobileLeadConversionController.searchContacts';
import convertLeadForMobile from '@salesforce/apex/MobileLeadConversionController.convertLeadForMobile';

export default class MobileLeadConvert extends NavigationMixin(LightningElement) {
    @api recordId;

    isLoading = true;
    isConverting = false;

    convertedStatusOptions = [];
    convertedStatus;

    accountMode = 'new';
    contactMode = 'new';

    newAccountName = '';
    newContactFirstName = '';
    newContactLastName = '';
    opportunityName = '';

    accountSearchTerm = '';
    accountResults = [];
    selectedAccountId;
    selectedAccountName = '';

    contactSearchTerm = '';
    contactResults = [];
    selectedContactId;
    selectedContactName = '';

    doNotCreateOpportunity = false;

    accountSearchTimeout;
    contactSearchTimeout;

    connectedCallback() {
        this.loadContext();
    }

    async loadContext() {
        this.isLoading = true;
        try {
            const context = await getConversionContext({ leadId: this.recordId });

            const statuses = context.convertedStatuses || [];
            this.convertedStatusOptions = statuses.map(status => ({ label: status, value: status }));
            this.convertedStatus = context.defaultConvertedStatus;

            this.newAccountName = context.leadCompany || '';
            this.newContactFirstName = context.leadFirstName || '';
            this.newContactLastName = context.leadLastName || '';
            this.opportunityName = context.defaultOpportunityName || '';
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    get accountModeOptions() {
        return [
            { label: 'Create New Account', value: 'new' },
            { label: 'Choose Existing Account', value: 'existing' }
        ];
    }

    get contactModeOptions() {
        return [
            { label: 'Create New Contact', value: 'new' },
            { label: 'Choose Existing Contact', value: 'existing' }
        ];
    }

    get isNewAccountMode() {
        return this.accountMode === 'new';
    }

    get isExistingAccountMode() {
        return this.accountMode === 'existing';
    }

    get isNewContactMode() {
        return this.contactMode === 'new';
    }

    get isExistingContactMode() {
        return this.contactMode === 'existing';
    }

    get showOpportunityName() {
        return !this.doNotCreateOpportunity;
    }

    get disableConvert() {
        if (!this.convertedStatus || this.isConverting || this.isLoading) {
            return true;
        }

        if (this.isNewAccountMode && !this.newAccountName?.trim()) {
            return true;
        }

        if (this.isExistingAccountMode && !this.selectedAccountId) {
            return true;
        }

        if (this.isNewContactMode && !this.newContactLastName?.trim()) {
            return true;
        }

        if (this.isExistingContactMode && !this.selectedContactId) {
            return true;
        }

        if (!this.doNotCreateOpportunity && !this.opportunityName?.trim()) {
            return true;
        }

        return false;
    }

    handleConvertedStatusChange(event) {
        this.convertedStatus = event.detail.value;
    }

    handleAccountModeChange(event) {
        this.accountMode = event.detail.value;
        this.accountSearchTerm = '';
        this.accountResults = [];
        this.selectedAccountId = null;
        this.selectedAccountName = '';
    }

    handleContactModeChange(event) {
        this.contactMode = event.detail.value;
        this.contactSearchTerm = '';
        this.contactResults = [];
        this.selectedContactId = null;
        this.selectedContactName = '';
    }

    handleNewAccountNameChange(event) {
        this.newAccountName = event.target.value;
    }

    handleNewContactFirstNameChange(event) {
        this.newContactFirstName = event.target.value;
    }

    handleNewContactLastNameChange(event) {
        this.newContactLastName = event.target.value;
    }

    handleOpportunityNameChange(event) {
        this.opportunityName = event.target.value;
    }

    handleDoNotCreateOpportunity(event) {
        this.doNotCreateOpportunity = event.target.checked;
    }

    handleAccountSearchChange(event) {
        this.accountSearchTerm = event.target.value;
        this.selectedAccountId = null;
        this.selectedAccountName = '';

        window.clearTimeout(this.accountSearchTimeout);
        this.accountSearchTimeout = window.setTimeout(() => {
            this.performAccountSearch();
        }, 300);
    }

    async performAccountSearch() {
        if (!this.accountSearchTerm || this.accountSearchTerm.trim().length < 2) {
            this.accountResults = [];
            return;
        }

        try {
            const results = await searchAccounts({ searchTerm: this.accountSearchTerm });
            this.accountResults = (results || []).map(item => ({ id: item.Id, name: item.Name }));
        } catch (error) {
            this.showError(error);
        }
    }

    handleAccountSelect(event) {
        this.selectedAccountId = event.currentTarget.dataset.id;
        this.selectedAccountName = event.currentTarget.dataset.name;
        this.accountResults = [];

        this.selectedContactId = null;
        this.selectedContactName = '';
        this.contactSearchTerm = '';
        this.contactResults = [];
    }

    handleContactSearchChange(event) {
        this.contactSearchTerm = event.target.value;
        this.selectedContactId = null;
        this.selectedContactName = '';

        window.clearTimeout(this.contactSearchTimeout);
        this.contactSearchTimeout = window.setTimeout(() => {
            this.performContactSearch();
        }, 300);
    }

    async performContactSearch() {
        if (!this.selectedAccountId) {
            this.contactResults = [];
            return;
        }

        if (!this.contactSearchTerm || this.contactSearchTerm.trim().length < 2) {
            this.contactResults = [];
            return;
        }

        try {
            const results = await searchContacts({ accountId: this.selectedAccountId, searchTerm: this.contactSearchTerm });
            this.contactResults = (results || []).map(item => ({ id: item.Id, name: item.Name }));
        } catch (error) {
            this.showError(error);
        }
    }

    handleContactSelect(event) {
        this.selectedContactId = event.currentTarget.dataset.id;
        this.selectedContactName = event.currentTarget.dataset.name;
        this.contactResults = [];
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleConvert() {
        this.isConverting = true;
        try {
            const result = await convertLeadForMobile({
                leadId: this.recordId,
                convertedStatus: this.convertedStatus,
                ownerId: null,
                useExistingAccount: this.isExistingAccountMode,
                existingAccountId: this.selectedAccountId,
                newAccountName: this.newAccountName,
                useExistingContact: this.isExistingContactMode,
                existingContactId: this.selectedContactId,
                newContactFirstName: this.newContactFirstName,
                newContactLastName: this.newContactLastName,
                doNotCreateOpportunity: this.doNotCreateOpportunity,
                opportunityName: this.opportunityName
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Lead converted successfully.',
                    variant: 'success'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());

            const navigationRecordId = result.opportunityId || result.accountId || result.contactId;
            if (navigationRecordId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: navigationRecordId,
                        actionName: 'view'
                    }
                });
            }
        } catch (error) {
            this.showError(error);
        } finally {
            this.isConverting = false;
        }
    }

    showError(error) {
        let message = 'Something went wrong.';
        if (error?.body?.message) {
            message = error.body.message;
        } else if (error?.message) {
            message = error.message;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error'
            })
        );
    }
}