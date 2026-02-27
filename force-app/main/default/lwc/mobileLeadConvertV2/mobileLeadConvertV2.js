import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getConversionContext from '@salesforce/apex/MobileLeadConversionController.getConversionContext';
import searchAccounts from '@salesforce/apex/MobileLeadConversionController.searchAccounts';
import searchContacts from '@salesforce/apex/MobileLeadConversionController.searchContacts';
import searchOpportunities from '@salesforce/apex/MobileLeadConversionController.searchOpportunities';
import getContactSummary from '@salesforce/apex/MobileLeadConversionController.getContactSummary';
import getOpportunitySummary from '@salesforce/apex/MobileLeadConversionController.getOpportunitySummary';
import convertLeadForMobile from '@salesforce/apex/MobileLeadConversionController.convertLeadForMobile';

export default class MobileLeadConvertV2 extends NavigationMixin(LightningElement) {
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
    ownerId;
    ownerName = '';

    accountMode = 'new';
    contactMode = 'new';
    opportunityMode = 'new';
    doNotCreateOpportunity = false;

    newAccountName = '';
    newContactFirstName = '';
    newContactLastName = '';
    opportunityName = '';

    accountSearchTerm = '';
    accountResults = [];
    selectedAccountId = null;
    selectedAccountName = '';
    contactSearchTerm = '';
    contactResults = [];
    selectedContactId = null;
    selectedContactName = '';
    opportunitySearchTerm = '';
    opportunityResults = [];
    selectedOpportunityId = null;
    selectedOpportunityName = '';
    accountSearchTimeout = null;
    contactSearchTimeout = null;
    opportunitySearchTimeout = null;

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
            this.ownerId = context.ownerId;
            this.ownerName = context.ownerName || '';

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
    get isNewOpportunityMode() {
        return this.opportunityMode === 'new';
    }
    get isExistingOpportunityMode() {
        return this.opportunityMode === 'existing';
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

    get opportunityModeOptions() {
        return [
            { label: 'Create New Opportunity', value: 'new' },
            { label: 'Choose Existing Opportunity', value: 'existing' }
        ];
    }

    get showOpportunityName() {
        return !this.doNotCreateOpportunity && this.isNewOpportunityMode;
    }

    get showExistingOpportunityLookup() {
        return !this.doNotCreateOpportunity && this.isExistingOpportunityMode;
    }

    get disableExistingContactLookup() {
        return false;
    }

    get disableExistingOpportunityLookup() {
        return false;
    }

    get opportunityLookupFilter() {
        if (!this.selectedAccountId) {
            return null;
        }

        return {
            criteria: [{
                fieldPath: 'AccountId',
                operator: 'eq',
                value: this.selectedAccountId
            }]
        };
    }

    get disableConvert() {
        if (!this.effectiveLeadId || !this.convertedStatus || this.isConverting || this.isLoading) {
            return true;
        }

        if (this.isNewAccountMode && !this.newAccountName?.trim()) {
            return true;
        }

        if (this.isNewContactMode && !this.newContactLastName?.trim()) {
            return true;
        }

        if (this.isExistingContactMode && !this.selectedContactId) {
            return true;
        }

        if (!this.doNotCreateOpportunity) {
            if (this.isNewOpportunityMode && !this.opportunityName?.trim()) {
                return true;
            }

            if (this.isExistingOpportunityMode && !this.selectedOpportunityId) {
                return true;
            }
        }

        return false;
    }

    handleConvertedStatusChange(event) {
        this.convertedStatus = event.detail.value;
    }

    handleAccountModeChange(event) {
        this.accountMode = event.detail.value;
        this.accountResults = [];
        this.accountSearchTerm = '';
        this.selectedAccountId = null;
        this.selectedAccountName = '';
        this.selectedContactId = null;
        this.selectedContactName = '';
        this.contactResults = [];
        this.contactSearchTerm = '';
        this.selectedOpportunityId = null;
        this.selectedOpportunityName = '';
        this.opportunityResults = [];
        this.opportunitySearchTerm = '';
    }

    handleExistingAccountChange(event) {
        this.selectedAccountId = event.detail.recordId || null;
        this.selectedAccountName = '';
        this.selectedContactId = null;
        this.selectedContactName = '';
        this.contactResults = [];
        this.contactSearchTerm = '';
        this.selectedOpportunityId = null;
        this.selectedOpportunityName = '';
        this.opportunityResults = [];
        this.opportunitySearchTerm = '';
    }

    handleContactModeChange(event) {
        this.contactMode = event.detail.value;
        this.contactResults = [];
        this.contactSearchTerm = '';
        this.selectedContactId = null;
        this.selectedContactName = '';
    }

    async handleExistingContactChange(event) {
        this.selectedContactId = event.detail.recordId || null;
        this.selectedContactName = '';

        if (!this.selectedContactId) {
            return;
        }

        try {
            const contact = await getContactSummary({ contactId: this.selectedContactId });
            if (contact?.AccountId) {
                this.accountMode = 'existing';
                this.selectedAccountId = contact.AccountId;
            }
        } catch (error) {
            this.showError(error);
        }
    }

    async handleExistingOpportunityChange(event) {
        this.selectedOpportunityId = event.detail.recordId || null;
        this.selectedOpportunityName = '';

        if (!this.selectedOpportunityId) {
            return;
        }

        try {
            const opportunity = await getOpportunitySummary({ opportunityId: this.selectedOpportunityId });
            if (opportunity?.AccountId) {
                this.accountMode = 'existing';
                this.selectedAccountId = opportunity.AccountId;
            }
        } catch (error) {
            this.showError(error);
        }
    }

    handleOpportunityModeChange(event) {
        this.opportunityMode = event.detail.value;
        this.opportunityResults = [];
        this.opportunitySearchTerm = '';
        this.selectedOpportunityId = null;
        this.selectedOpportunityName = '';
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
        if (this.doNotCreateOpportunity) {
            this.selectedOpportunityId = null;
            this.selectedOpportunityName = '';
            this.opportunityResults = [];
            this.opportunitySearchTerm = '';
        }
    }

    handleAccountSearchChange(event) {
        this.accountSearchTerm = event.target.value;
        this.selectedAccountId = null;
        this.selectedAccountName = '';

        if (this.accountSearchTimeout) {
            clearTimeout(this.accountSearchTimeout);
        }

        this.accountSearchTimeout = setTimeout(() => {
            this.performAccountSearch();
        }, 300);
    }

    async performAccountSearch() {
        const term = this.accountSearchTerm?.trim();
        if (!term || term.length < 2) {
            this.accountResults = [];
            return;
        }

        try {
            const records = await searchAccounts({ searchTerm: term });
            this.accountResults = (records || []).map(account => ({
                id: account.Id,
                name: account.Name
            }));
        } catch (error) {
            this.accountResults = [];
            this.showError(error);
        }
    }

    handleAccountSelect(event) {
        this.selectedAccountId = event.currentTarget.dataset.id;
        this.selectedAccountName = event.currentTarget.dataset.name;
        this.accountResults = [];
        this.accountSearchTerm = this.selectedAccountName;
        this.selectedContactId = null;
        this.selectedContactName = '';
        this.contactResults = [];
        this.contactSearchTerm = '';
        this.selectedOpportunityId = null;
        this.selectedOpportunityName = '';
        this.opportunityResults = [];
        this.opportunitySearchTerm = '';
    }

    handleContactSearchChange(event) {
        this.contactSearchTerm = event.target.value;
        this.selectedContactId = null;
        this.selectedContactName = '';

        if (this.contactSearchTimeout) {
            clearTimeout(this.contactSearchTimeout);
        }

        this.contactSearchTimeout = setTimeout(() => {
            this.performContactSearch();
        }, 300);
    }

    async performContactSearch() {
        const term = this.contactSearchTerm?.trim();
        if (!this.selectedAccountId || !term || term.length < 2) {
            this.contactResults = [];
            return;
        }

        try {
            const records = await searchContacts({
                accountId: this.selectedAccountId,
                searchTerm: term
            });
            this.contactResults = (records || []).map(contact => ({
                id: contact.Id,
                name: contact.Name
            }));
        } catch (error) {
            this.contactResults = [];
            this.showError(error);
        }
    }

    handleContactSelect(event) {
        this.selectedContactId = event.currentTarget.dataset.id;
        this.selectedContactName = event.currentTarget.dataset.name;
        this.contactResults = [];
        this.contactSearchTerm = this.selectedContactName;
    }

    handleOpportunitySearchChange(event) {
        this.opportunitySearchTerm = event.target.value;
        this.selectedOpportunityId = null;
        this.selectedOpportunityName = '';

        if (this.opportunitySearchTimeout) {
            clearTimeout(this.opportunitySearchTimeout);
        }

        this.opportunitySearchTimeout = setTimeout(() => {
            this.performOpportunitySearch();
        }, 300);
    }

    async performOpportunitySearch() {
        const term = this.opportunitySearchTerm?.trim();
        if (!this.selectedAccountId || !term || term.length < 2) {
            this.opportunityResults = [];
            return;
        }

        try {
            const records = await searchOpportunities({
                accountId: this.selectedAccountId,
                searchTerm: term
            });
            this.opportunityResults = (records || []).map(opportunity => ({
                id: opportunity.Id,
                name: opportunity.Name
            }));
        } catch (error) {
            this.opportunityResults = [];
            this.showError(error);
        }
    }

    handleOpportunitySelect(event) {
        this.selectedOpportunityId = event.currentTarget.dataset.id;
        this.selectedOpportunityName = event.currentTarget.dataset.name;
        this.opportunityResults = [];
        this.opportunitySearchTerm = this.selectedOpportunityName;
    }

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
                ownerId: this.ownerId,
                useExistingAccount: this.isExistingAccountMode,
                existingAccountId: this.selectedAccountId,
                newAccountName: this.newAccountName,
                useExistingContact: this.isExistingContactMode,
                existingContactId: this.selectedContactId,
                newContactFirstName: this.newContactFirstName,
                newContactLastName: this.newContactLastName,
                doNotCreateOpportunity: this.doNotCreateOpportunity || this.isExistingOpportunityMode,
                opportunityName: this.isNewOpportunityMode ? this.opportunityName : null,
                useExistingOpportunity: this.isExistingOpportunityMode,
                existingOpportunityId: this.selectedOpportunityId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Lead converted successfully.',
                    variant: 'success'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());

            const navigationRecordId = result.accountId || result.contactId || result.opportunityId;
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