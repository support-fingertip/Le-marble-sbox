import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getConversionContext from '@salesforce/apex/MobileLeadConversionController.getConversionContext';
import searchAccounts from '@salesforce/apex/MobileLeadConversionController.searchAccounts';
import searchContacts from '@salesforce/apex/MobileLeadConversionController.searchContacts';
import convertLeadForMobile from '@salesforce/apex/MobileLeadConversionController.convertLeadForMobile';

export default class MobileLeadConvert extends NavigationMixin(LightningElement) {
    _recordId;
    currentPageReference;
    hasLoadedContext = false;
    isContextLoading = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        this.initializeContextIfReady();
    }

    isLoading = true;
    isConverting = false;

    convertedStatusOptions = [];
    convertedStatus;

    // Always auto-create new Account, Contact, Opportunity
    accountMode = 'new';
    contactMode = 'new';
    doNotCreateOpportunity = false;

    newAccountName = '';
    newContactFirstName = '';
    newContactLastName = '';
    opportunityName = '';

    // Hide all lookup/search UI
    accountSearchTerm = '';
    accountResults = [];
    selectedAccountId = null;
    selectedAccountName = '';
    contactSearchTerm = '';
    contactResults = [];
    selectedContactId = null;
    selectedContactName = '';
    accountSearchTimeout = null;
    contactSearchTimeout = null;

    connectedCallback() {
        this.initializeContextIfReady();
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageReference) {
        this.currentPageReference = pageReference;
        if (!this._recordId) {
            this._recordId = this.extractLeadIdFromPageReference(pageReference);
        }
        this.initializeContextIfReady();
    }

    get effectiveLeadId() {
        return this._recordId || this.extractLeadIdFromPageReference(this.currentPageReference);
    }

    extractLeadIdFromPageReference(pageReference) {
        if (!pageReference) {
            return null;
        }

        const inContextRecordId = this.extractRecordIdFromInContext(pageReference?.state?.inContextOfRef);

        return (
            pageReference?.attributes?.recordId ||
            pageReference?.state?.recordId ||
            pageReference?.state?.c__recordId ||
            inContextRecordId ||
            null
        );
    }

    extractRecordIdFromInContext(inContextOfRef) {
        if (!inContextOfRef) {
            return null;
        }

        try {
            const encodedContext = inContextOfRef.startsWith('1.')
                ? inContextOfRef.substring(2)
                : inContextOfRef;
            const decodedContext = atob(encodedContext);
            const context = JSON.parse(decodedContext);

            return (
                context?.attributes?.recordId ||
                context?.state?.recordId ||
                context?.state?.c__recordId ||
                null
            );
        } catch (error) {
            return null;
        }
    }

    initializeContextIfReady() {
        if (this.hasLoadedContext || this.isContextLoading) {
            return;
        }

        const leadId = this.effectiveLeadId;
        if (!leadId) {
            return;
        }

        this.loadContext();
    }

    async loadContext() {
        this.isContextLoading = true;
        this.isLoading = true;
        try {
            const context = await getConversionContext({ leadId: this.effectiveLeadId });

            const statuses = context.convertedStatuses || [];
            this.convertedStatusOptions = statuses.map(status => ({ label: status, value: status }));
            this.convertedStatus = context.defaultConvertedStatus;

            this.newAccountName = context.leadCompany || '';
            this.newContactFirstName = context.leadFirstName || '';
            this.newContactLastName = context.leadLastName || '';
            this.opportunityName = context.defaultOpportunityName || '';
            this.hasLoadedContext = true;
        } catch (error) {
            this.showError(error);
        } finally {
            this.isContextLoading = false;
            this.isLoading = false;
        }
    }

    // Hide radio options, always new
    get accountModeOptions() {
        return [
            { label: 'Create New Account', value: 'new' }
        ];
    }

    get contactModeOptions() {
        return [
            { label: 'Create New Contact', value: 'new' }
        ];
    }

    get isNewAccountMode() {
        return true;
    }
    get isExistingAccountMode() {
        return false;
    }
    get isNewContactMode() {
        return true;
    }
    get isExistingContactMode() {
        return false;
    }

    get showOpportunityName() {
        return !this.doNotCreateOpportunity;
    }

    get disableConvert() {
        if (!this.effectiveLeadId || !this.convertedStatus || this.isConverting || this.isLoading) {
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

    // Remove handlers for switching modes
    handleAccountModeChange(event) {}
    handleContactModeChange(event) {}

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

    // Remove all search/lookup handlers (UI will be hidden)
    handleAccountSearchChange(event) {}
    async performAccountSearch() {}
    handleAccountSelect(event) {}
    handleContactSearchChange(event) {}
    async performContactSearch() {}
    handleContactSelect(event) {}

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleConvert() {
        if (!this.effectiveLeadId) {
            this.showError({ message: 'Lead Id is not available. Please reopen this action from a Lead record.' });
            return;
        }

        this.isConverting = true;
        try {
            const result = await convertLeadForMobile({
                leadId: this.effectiveLeadId,
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
        const message = this.getFriendlyErrorMessage(error);

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to Convert Lead',
                message,
                variant: 'error'
            })
        );
    }

    getFriendlyErrorMessage(error) {
        let message = 'Please check required fields and try again.';

        if (error?.body?.output?.errors?.length) {
            message = error.body.output.errors[0].message;
        } else if (error?.body?.output?.fieldErrors) {
            const fieldErrors = Object.values(error.body.output.fieldErrors)
                .flat()
                .map(entry => entry?.message)
                .filter(Boolean);
            if (fieldErrors.length) {
                message = fieldErrors[0];
            }
        } else if (error?.body?.message) {
            message = error.body.message;
        } else if (error?.message) {
            message = error.message;
        }

        message = message
            .replace(/^Error converting lead:\s*/i, '')
            .replace(/ConvertLead failed\.\s*First exception on row \d+; first error:\s*/i, '')
            .replace(/FIELD_CUSTOM_VALIDATION_EXCEPTION,\s*/gi, '')
            .replace(/^Validation error on Lead:\s*/i, '')
            .replace(/:\s*\[\]\s*$/g, '')
            .replace(/\s{2,}/g, ' ')
            .trim();

        if (!message) {
            return 'Please check required fields and try again.';
        }

        return /[.!?]$/.test(message) ? message : `${message}.`;
    }
}