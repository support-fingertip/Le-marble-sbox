import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getOpenOpportunitiesForAccount from '@salesforce/apex/NewQuoteController.getOpenOpportunitiesForAccount';

const DEFAULT_STAGE = 'Open';
const DEFAULT_CLOSE_DAYS = 30;

const ACCOUNT_FIELDS = [
    'Account.Name',
    'Account.Address_Line1__c',
    'Account.Address_Line2__c',
    'Account.Address_Line3__c',
    'Account.Village__c',
    'Account.Panchayath__c',
    'Account.Municipality__c',
    'Account.Corporation__c',
    'Account.District__c',
    'Account.State__c',
    'Account.Country__c',
    'Account.Pin_Code__c'
];

export default class QuoteOpportunityPicker extends LightningElement {

    @api accountId;

    @track opportunities = [];
    @track loaded = false;
    @track showNewOpportunityForm = false;
    @track sameAsAccount = false;

    @track addressLine1 = '';   // House Name / No
    @track addressLine2 = '';   // Place
    @track addressLine3 = '';   // Address Line 3
    @track village = '';
    @track panchayath = '';
    @track municipality = '';
    @track corporation = '';
    @track district = '';
    @track state = '';
    @track country = '';
    @track pincode = '';
    @track branchLocation = '';
    @track productCategory = '';

    _wiredAccountResult;

    @wire(getOpenOpportunitiesForAccount, { accountId: '$accountId' })
    wiredOpps({ data, error }) {
        if (data) {
            this.opportunities = data;
            this.loaded = true;
        } else if (error) {
            this.opportunities = [];
            this.loaded = true;
            this.toast('Error', this.extractError(error), 'error');
        }
    }

    @wire(getRecord, { recordId: '$accountId', fields: ACCOUNT_FIELDS })
    wiredAccount(result) {
        this._wiredAccountResult = result;
    }

    get hasOpportunities() {
        return this.opportunities && this.opportunities.length > 0;
    }

    get accountName() {
        const data = this._wiredAccountResult && this._wiredAccountResult.data;
        return data ? getFieldValue(data, 'Account.Name') : '';
    }

    get defaultCloseDate() {
        const d = new Date();
        d.setDate(d.getDate() + DEFAULT_CLOSE_DAYS);
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${y}-${m}-${day}`;
    }

    handleOpportunityClick(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.dispatchSelected(id, name);
    }

    handleShowNewOppForm() {
        this.showNewOpportunityForm = true;
    }

    handleCancelNewOpp() {
        this.showNewOpportunityForm = false;
        this.resetAddress();
    }

    handleSameAsAccount(event) {
        this.sameAsAccount = event.target.checked;
        if (this.sameAsAccount) {
            this.copyAddressFromAccount();
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        const value = (event.detail && event.detail.value !== undefined)
            ? event.detail.value
            : event.target.value;
        this[field] = value;
        if (this.sameAsAccount && field !== 'branchLocation') {
            this.sameAsAccount = false;
        }
    }

    copyAddressFromAccount() {
        const data = this._wiredAccountResult && this._wiredAccountResult.data;
        if (!data) {
            this.toast('No address', 'This account has no shipping address yet.', 'warning');
            this.sameAsAccount = false;
            return;
        }
        this.addressLine1 = getFieldValue(data, 'Account.Address_Line1__c') || '';
        this.addressLine2 = getFieldValue(data, 'Account.Address_Line2__c') || '';
        this.addressLine3 = getFieldValue(data, 'Account.Address_Line3__c') || '';
        this.village      = getFieldValue(data, 'Account.Village__c') || '';
        this.panchayath   = getFieldValue(data, 'Account.Panchayath__c') || '';
        this.municipality = getFieldValue(data, 'Account.Municipality__c') || '';
        this.corporation  = getFieldValue(data, 'Account.Corporation__c') || '';
        this.district     = getFieldValue(data, 'Account.District__c') || '';
        this.state        = getFieldValue(data, 'Account.State__c') || '';
        this.country      = getFieldValue(data, 'Account.Country__c') || '';
        const pin         = getFieldValue(data, 'Account.Pin_Code__c');
        this.pincode      = (pin === null || pin === undefined) ? '' : String(pin);
    }

    resetAddress() {
        this.sameAsAccount = false;
        this.addressLine1 = '';
        this.addressLine2 = '';
        this.addressLine3 = '';
        this.village = '';
        this.panchayath = '';
        this.municipality = '';
        this.corporation = '';
        this.district = '';
        this.state = '';
        this.country = '';
        this.pincode = '';
        this.branchLocation = '';
        this.productCategory = '';
    }

    handleOpportunitySubmit(event) {
        event.preventDefault();
        if (!this.accountId) {
            this.toast('Missing account', 'Cannot create an opportunity without the visit account.', 'error');
            return;
        }
        const fields = event.detail.fields || {};
        fields.AccountId = this.accountId;
        fields.StageName = DEFAULT_STAGE;
        fields.CloseDate = this.defaultCloseDate;

        fields.AddressLine1__c = this.addressLine1;
        fields.AddressLine2__c = this.addressLine2;
        fields.AddressLine3__c = this.addressLine3;
        fields.Village__c      = this.village;
        fields.Panchayath__c   = this.panchayath;
        fields.Municipality__c = this.municipality;
        fields.Corporation__c  = this.corporation;
        fields.District__c     = this.district;
        fields.State__c        = this.state;
        fields.Country__c      = this.country;
        fields.Pin_Code__c     = this.pincode === '' ? null : Number(this.pincode);
        fields.Branch_Location__c = this.branchLocation;
        fields.Product_Category__c = this.productCategory;
        fields.Same_as_Account_Ship_Address__c = this.sameAsAccount;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleOpportunityCreated(event) {
        const newId = event.detail.id;
        this.toast('Success', 'Opportunity created.', 'success');
        this.showNewOpportunityForm = false;
        this.dispatchSelected(newId, '');
    }

    handleOpportunityCreateError(event) {
        const msg = (event && event.detail && event.detail.message) || 'Failed to create opportunity.';
        this.toast('Error', msg, 'error');
    }

    dispatchSelected(opportunityId, opportunityName) {
        this.dispatchEvent(new CustomEvent('oppselected', {
            detail: { opportunityId, opportunityName }
        }));
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (!error) return 'Unknown error';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
