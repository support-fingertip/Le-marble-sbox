import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchArchitects from '@salesforce/apex/EngagementController.searchArchitectsByPhone';
import createEngagement from '@salesforce/apex/EngagementController.createEngagement';
import getInfluencerTypes from '@salesforce/apex/EngagementController.getInfluencerTypePicklistValues';
import getEngagementTypes from '@salesforce/apex/EngagementController.getEngagementTypePicklistValues';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import { NavigationMixin } from 'lightning/navigation';

export default class EngagementModal extends NavigationMixin(LightningElement) {
    @api recordId;
    @track engagementId = 'Auto-generated';
    @track ownerName = '';
    @track createdByName = '';
    @track lastModifiedByName = '';
    
    @track architectSearchTerm = '';
    @track architectSearchResults = [];
    @track showArchitectResults = false;
    @track selectedArchitect = null;
    
    @track selectedDate = new Date().toISOString().split('T')[0];
    @track selectedTime = new Date().toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' });
    
    @track influencerTypeOptions = [];
    @track engagementTypeOptions = [];
    
    @track engagementData = {
        architectId: '',
        dateTime: null,
        influencerType: '',
        engagementType: '',
        notes: ''
    };

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD] })
    userInfo({ error, data }) {
        if (data) {
            this.ownerName = data.fields.Name.value;
            this.createdByName = data.fields.Name.value;
            this.lastModifiedByName = data.fields.Name.value;
        } else if (error) {
            console.error('Error fetching user details:', error);
        }
    }

    connectedCallback() {
        // Fetch picklist values
        this.loadPicklistValues();
        
        // Initialize the dateTime value
        this.updateDateTime();
    }

    async loadPicklistValues() {
        try {
            // Fetch Influencer Type options
            this.influencerTypeOptions = await getInfluencerTypes();
            
            // Fetch Engagement Type options
            this.engagementTypeOptions = await getEngagementTypes();
        } catch (error) {
            console.error('Error loading picklist values:', error);
            this.dispatchToast('Error', 'Failed to load picklist values', 'error');
        }
    }

    handleArchitectSearch(event) {
        const searchTerm = event.target.value;
        this.architectSearchTerm = searchTerm;
        
        if (searchTerm.length >= 3) {
            searchArchitects({ phoneNumber: searchTerm })
                .then(results => {
                    this.architectSearchResults = results;
                    this.showArchitectResults = results.length > 0;
                })
                .catch(error => {
                    console.error('Error searching architects:', error);
                    this.dispatchToast('Error', 'Failed to search architects', 'error');
                });
        } else {
            this.showArchitectResults = false;
            this.architectSearchResults = [];
        }
    }

    selectArchitect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.architectSearchResults.find(arch => arch.Id === selectedId);
        if (selected) {
            this.selectedArchitect = selected;
            this.architectSearchTerm = selected.Name;
            this.engagementData.architectId = selected.Id;
            this.showArchitectResults = false;
        }
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
        this.updateDateTime();
    }

    handleTimeChange(event) {
        this.selectedTime = event.target.value;
        this.updateDateTime();
    }

    updateDateTime() {
        if (this.selectedDate && this.selectedTime) {
            // Create a date object in UTC
            const dateStr = `${this.selectedDate}T${this.selectedTime}`;
            const date = new Date(dateStr);
            
            // Format date for Salesforce
            this.engagementData.dateTime = date.toISOString();
        }
    }

    handleInfluencerTypeChange(event) {
        this.engagementData.influencerType = event.target.value;
    }

    handleEngagementTypeChange(event) {
        this.engagementData.engagementType = event.target.value;
    }

    handleNotesChange(event) {
        this.engagementData.notes = event.target.value;
    }

    validateFields() {
        const requiredFields = ['architectId', 'dateTime', 'influencerType', 'engagementType'];
        const missingFields = requiredFields.filter(field => !this.engagementData[field]);
        
        if (missingFields.length > 0) {
            const fieldLabels = {
                architectId: 'Architect',
                dateTime: 'Date and Time',
                influencerType: 'Influencer Type',
                engagementType: 'Engagement Type'
            };
            
            this.dispatchToast(
                'Error',
                `Please fill in all required fields: ${missingFields.map(f => fieldLabels[f]).join(', ')}`,
                'error'
            );
            return false;
        }
        return true;
    }

    async handleSave() {
        if (!this.validateFields()) return;

        try {
            const result = await createEngagement({ engagementData: this.engagementData });
            this.dispatchToast('Success', 'Engagement created successfully', 'success');
            
            // Navigate to the new engagement record page
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result,
                    objectApiName: 'Engagement__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            console.error('Error creating engagement:', error);
            this.dispatchToast('Error', 'Failed to create engagement', 'error');
        }
    }

    async handleSaveAndNew() {
        if (!this.validateFields()) return;

        try {
            const result = await createEngagement({ engagementData: this.engagementData });
            this.dispatchToast('Success', 'Engagement created successfully', 'success');
            this.resetForm();
        } catch (error) {
            console.error('Error creating engagement:', error);
            this.dispatchToast('Error', 'Failed to create engagement', 'error');
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    resetForm() {
        this.engagementData = {
            architectId: '',
            dateTime: null,
            influencerType: '',
            engagementType: '',
            notes: ''
        };
        this.architectSearchTerm = '';
        this.selectedArchitect = null;
        this.selectedDate = new Date().toISOString().split('T')[0];
        this.selectedTime = new Date().toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' });
        
        // Reset all input fields
        this.template.querySelectorAll('input, select, textarea').forEach(field => {
            field.value = '';
        });
    }

    dispatchToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}