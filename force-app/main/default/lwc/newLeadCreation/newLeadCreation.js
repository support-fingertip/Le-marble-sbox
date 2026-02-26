import { LightningElement, track, wire,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

// import createLead from '@salesforce/apex/CustomerEntryController.createLead';
import searchArchitects from '@salesforce/apex/CustomerEntryController.searchArchitects';
import createArchitect from '@salesforce/apex/CustomerEntryController.createArchitect';
import searchCustomers from '@salesforce/apex/CustomerEntryController.searchCustomers';
import searchContractors from '@salesforce/apex/CustomerEntryController.searchContractors';
import createContractor from '@salesforce/apex/CustomerEntryController.createContractor';
import searchMaisons from '@salesforce/apex/CustomerEntryController.searchMaisons';
import createMaison from '@salesforce/apex/CustomerEntryController.createMaison';
import getExecutives from '@salesforce/apex/CustomerEntryController.getExecutives';
import createLead from '@salesforce/apex/StandardLeadController.createLead';

import getReferenceTypes from '@salesforce/apex/CustomerEntryController.getReferenceTypes';
import getLeadSources from '@salesforce/apex/CustomerEntryController.getLeadSources';
import checkReferredCustomer from '@salesforce/apex/CustomerEntryController.checkReferredCustomer';
import checkReferralExists from '@salesforce/apex/CustomerEntryController.checkReferralExists';
import getSocialMediaPlatforms from '@salesforce/apex/CustomerEntryController.getSocialMediaPlatforms';
//import getCustomerTypes from '@salesfor@ce/apex/CustomerEntryController.getCustomerTypes';
import getLeadSourcesStd from '@salesforce/apex/StandardLeadController.getLeadSources';
import getLeadTypes from '@salesforce/apex/StandardLeadController.getLeadTypes';
import getSalutationsStd from '@salesforce/apex/StandardLeadController.getSalutations';
import getStatesStd from '@salesforce/apex/StandardLeadController.getStates';
import getCountriesStd from '@salesforce/apex/StandardLeadController.getCountries';
import getDistrictsStd from '@salesforce/apex/StandardLeadController.getDistricts';
import getPanchayathsStd from '@salesforce/apex/StandardLeadController.getPanchayaths';


export default class NewLeadCreation extends NavigationMixin(LightningElement) {
    @track customerData = {
        salutation: '',
        firstName: '',
        lastName: '',
        company: '',
        primaryPhone: '',
        secondaryPhone: '',
        email: '',
        street: '',
        state: '',
        district: '',
        pinCode: '',
        country: '',
        customerSource: '',
        referenceType: '',
        referenceArchitect: '',
        customerId: '',
        leadType: '',
        leadPurpose: '',
        customerEntryDate: new Date().toISOString().split('T')[0],
        assignedExecutive: '',
        remarks: '',
        referralName: '',
        phoneNumber: '',
        socialMedia: '',
        type: '',
        pocName: '',
        pocContactNo: '',
        pocEmail: '',
        panchayat: '',
        Company:'',
    };
    
    // Add getter for minimum date
    get minDate() {
        return new Date().toISOString().split('T')[0];
    }
    
    @track executives = [];
       @api recordId;
    // Toast properties
    @track showToast = false;
    @track toastTitle = '';
    @track toastMessage = '';
    @track toastVariant = 'success'; // success, error, warning, info
    
    // Add a loading state property
    @track isLoading = false;
    
    // Reference search properties
    @track showReferenceFields = false;
    @track showArchitectFields = false;
    @track showCustomerFields = false;
    @track showContractorFields = false;
    @track showMaisonFields = false;
    @track showPhoneNumberField = false;
    @track showReferralNameField = false;
    @track showCustomerReferenceFields = false;

    @track architectSearchTerm = '';
    @track customerSearchTerm = '';
    @track contractorSearchTerm = '';
    @track maisonSearchTerm = '';

    @track architectSearchResults = [];
    @track customerSearchResults = [];
    @track contractorSearchResults = [];
    @track maisonSearchResults = [];

    @track showArchitectResults = false;
    @track showCustomerResults = false;
    @track showContractorResults = false;
    @track showMaisonResults = false;

    @track showAddNewOption = false;
    @track showAddNewContractorOption = false;
    @track showAddNewMaisonOption = false;

    // Modal properties for new entries
    @track showNewArchitectModal = false;
    @track showNewContractorModal = false;
    @track showNewMaisonModal = false;

    @track newArchitectData = { name: '', phoneNumber: '' };
    @track newContractorData = { name: '' };
    @track newMaisonData = { name: '' };

    @track noCustomerResults = false;

    @track citiesList = [];
    isCityDisabled = true;

    @track referenceTypes = [];
    @track leadSources = [];
    /*@track customerTypes = [];*/

    @track showReferralNameInput = false;
    @track referredCustomerExists = false;
    @track referredCustomerName = '';

    @track referralExists = false;
    @track referralName = '';
    @track referralId = '';

    @track showReferralPhoneField = false;

    @track showSocialMediaPlatforms = false;
    @track socialMediaPlatforms = [];

    @track showProjectFields = false;
    @track showNewProjectModal = false;
    @track showNewFirmModal = false;
    @track projectSearchTerm = '';
    @track firmSearchTerm = '';
    @track projectSearchResults = [];
    @track firmSearchResults = [];
    @track showProjectResults = false;
    @track showFirmResults = false;
    @track newProjectData = { name: '', firmId: '' };
    @track newFirmData = { name: '' };

    @track showPOCFields = false;

    @track duplicateRecordId = null;

    @track _hasRendered = false;

    @track phoneError = '';

    @track country = 'IN';
    @track phone = '';
    
    @track secondaryCountry = 'IN';

    @track panchayatList = [];
    isPanchayatDisabled = true;

    @track showDistrictAndPanchayat = false;

    @track secondaryPhoneError = '';

    @track panchayatSearchTerm = '';
    @track filteredPanchayatOptions = [];
    @track showPanchayatResults = false;

    @wire(getReferenceTypes)
    wiredReferenceTypes({ error, data }) {
        if (data) {
            this.referenceTypes = data;
        } else if (error) {
            console.error('Error fetching reference types:', error);
        }
    }

    @wire(getLeadSources)
    wiredLeadSources({ error, data }) {
        if (data) {
            this.leadSources = data;
        } else if (error) {
            console.error('Error fetching lead sources:', error);

        }
    }


    // STANDARD LEAD TYPES
    @track leadTypesStd = [];

    @wire(getLeadTypes)
    wiredLeadTypesStd({ error, data }) {
        if (data) {
            this.leadTypesStd = data;
                console.log('Standard Lead Types:', data);
                } else if (error) {
                    console.error('Error loading standard lead types:', error);
             }
            }



    @track leadSourcesStd = [];
    @track salutationOptionsStd = [];
    @track stateOptionsStd = [];
    @track countryOptionsStd = [];
    @track districtOptionsStd = [];
    @track panchayatOptionsStd = [];

    @wire(getLeadSourcesStd)
    wiredLeadSourcesStd({ error, data }) {
        if (data) {
            this.leadSourcesStd = data;
                console.log('Standard Lead Sources:', data);
                } else if (error) {
                    console.error('Error loading standard lead sources:', error);
                }
    }

    @wire(getSalutationsStd)
    wiredSalutationsStd({ error, data }) {
        if (data) {
            this.salutationOptionsStd = data;
        } else if (error) {
            console.error('Error loading salutations:', error);
        }
    }

    @wire(getStatesStd)
    wiredStatesStd({ error, data }) {
        if (data) {
            this.stateOptionsStd = data;
        } else if (error) {
            console.error('Error loading states:', error);
        }
    }

    @wire(getCountriesStd)
    wiredCountriesStd({ error, data }) {
        if (data) {
            this.countryOptionsStd = data;
        } else if (error) {
            console.error('Error loading countries:', error);
        }
    }

    @wire(getDistrictsStd)
    wiredDistrictsStd({ error, data }) {
        if (data) {
            this.districtOptionsStd = data;
        } else if (error) {
            console.error('Error loading districts:', error);
        }
    }

    @wire(getPanchayathsStd)
    wiredPanchayathsStd({ error, data }) {
        if (data) {
            this.panchayatOptionsStd = data;
        } else if (error) {
            console.error('Error loading panchayaths:', error);
        }
    }

   /* @wire(getCustomerTypes)
    wiredCustomerTypes({ error, data }) {
        if (data) {
            this.customerTypes = data;
        } else if (error) {
            console.error('Error fetching customer types:', error);
        }
    }*/

    @wire(getSocialMediaPlatforms)
    wiredSocialMediaPlatforms({ error, data }) {
        if (data) {
            this.socialMediaPlatforms = data;
        } else if (error) {
            console.error('Error fetching social media platforms:', error);
        }
    }

    // Getter for states list
    get statesList() {
        return this.stateOptionsStd;
    }

    get keralaDistrictsList() {
        return this.districtOptionsStd;
    }

    get panchayatOptions() {
        return this.panchayatOptionsStd;
    }

    get toastClass() {
        return `toast-container ${this.toastVariant}`;
    }
    
    get toastIcon() {
        switch(this.toastVariant) {
            case 'success': return '✓';
            case 'error': return '✕';
            case 'warning': return '!';
            case 'info': return 'i';
            default: return '';
        }
    }
    
    get toastStyle() {
        return this.duplicateRecordId ? 'cursor:pointer;' : '';
    }
    
    connectedCallback() {
        // Load executives when component is initialized
        this.loadExecutives();
    }
    
    loadExecutives() {
        getExecutives()
            .then(result => {
                console.log('Raw executives data:', result); // Log raw data
                this.executives = result;
                console.log('Executives loaded:', this.executives);
            })
            .catch(error => {
                console.error('Error loading executives', error);
                this.showErrorToast('Error loading executives', error.message);
            });
    }
    
    renderedCallback() {
        // No third-party library needed
    }
    
    handleInputChange(event) {
        const field = event.target.name;
        let value = event.target.value;
        this.customerData = { ...this.customerData, [field]: value };
    }
    
    handleUpperCaseInput(event) {
        const field = event.target.name;
        const value = event.target.value.toUpperCase();
        this.customerData = { ...this.customerData, [field]: value };
        event.target.value = value; // Update the input field value to uppercase
    }
    
    validateForm() {
        const allInputs = [...this.template.querySelectorAll('input, select')].filter(
            input => input.id !== 'assignedExecutive'
        );
        let isValid = true;
        
        allInputs.forEach(inputField => {
            if (inputField.required && !inputField.value) {
                inputField.classList.add('error');
                isValid = false;
            } else {
                inputField.classList.remove('error');
            }
        });
        
        // Validate required fields
        const requiredFields = {
            'firstName': 'First Name',
            'primaryPhone': 'Phone',
            'state': 'State',
            'customerSource': 'Lead Source',
            'customerEntryDate': 'Customer Entry Date',
            'type': 'Type'
        };

        const missingFields = [];
        for (const [field, label] of Object.entries(requiredFields)) {
            if (!this.customerData[field]) {
                missingFields.push(label);
            }
        }

        if (missingFields.length > 0) {
            this.displayToast('Error', `Required fields missing: ${missingFields.join(', ')}`, 'error');
            return false;
        }
        
        return isValid;
    }
    
    handleSave() {
        if (this.validateForm()) {
            this.isLoading = true;
            
            const saveData = { ...this.customerData };
            console.log('Saving customer data:', saveData);
            console.log('Architect ID before save:', saveData.referenceArchitect);
            
            // Remove empty fields to avoid validation issues
            if (!saveData.assignedExecutive) {
                delete saveData.assignedExecutive;
            }
            // Only delete referenceArchitect if it's completely empty (not just falsy)
            if (!saveData.referenceArchitect || saveData.referenceArchitect === '') {
                delete saveData.referenceArchitect;
            }
            if (!saveData.customerId || saveData.customerId === '') {
                delete saveData.customerId;
            }
            
            console.log('Final save data:', saveData);
            console.log('Architect ID in final save data:', saveData.referenceArchitect);
            
            // Call the Apex method to create the Customer
            createLead({ data: saveData })
               .then(result => {
                    this.isLoading = false;
                    this.displayToast('Success', 'Customer created successfully!', 'success');
                    
                    // Navigate to the newly created Customer record
                    this.navigateToRecord(result);
                    this.resetForm();
                })
                .catch(error => {
                    this.isLoading = false;
                    let errorMessage = 'Unknown error';
                    let duplicateId = null;
                    if (error.body && error.body.message) {
                        if (error.body.message.startsWith('DUPLICATE_FOUND:')) {
                            duplicateId = error.body.message.split(':')[1];
                            errorMessage = 'Duplicate record found. Click here to view the existing record.';
                        } else {
                            errorMessage = error.body.message;
                        }
                    } else if (error.message) {
                        errorMessage = error.message;
                    }
                    this.displayToast('Error', errorMessage, 'error', duplicateId);
                    console.error('Error creating record:', error);
                });
        }
    }
    
    handleCancel() {
        this.resetForm();
    }
    
    resetForm() {
        this.customerData = {
            salutation: '',
            firstName: '',
            lastName: '',
            company: '',
            primaryPhone: '',
            secondaryPhone: '',
            email: '',
            street: '',
            state: '',
            district: '',
            pinCode: '',
            country: '',
            customerSource: '',
            referenceType: '',
            referenceArchitect: '',
            customerId: '',
            leadType: '',
            leadPurpose: '',
            customerEntryDate: new Date().toISOString().split('T')[0],
            assignedExecutive: '',
            remarks: '',
            referralName: '',
            phoneNumber: '',
            socialMedia: '',
            type: '',
            pocName: '',
            pocContactNo: '',
            pocEmail: '',
            panchayat: '',
        };
        
        this.citiesList = [];
        this.isCityDisabled = true;
        this.isPanchayatDisabled = true;
        
        // Reset all input fields
        this.template.querySelectorAll('input, select').forEach(field => {
            field.value = '';
            field.classList.remove('error');
        });
        
        // Reset search terms
        this.architectSearchTerm = '';
        this.customerSearchTerm = '';
        this.contractorSearchTerm = '';
        this.maisonSearchTerm = '';
        
        // Reset search results
        this.architectSearchResults = [];
        this.customerSearchResults = [];
        this.contractorSearchResults = [];
        this.maisonSearchResults = [];
        
        // Reset display states
        this.showArchitectResults = false;
        this.showCustomerResults = false;
        this.showContractorResults = false;
        this.showMaisonResults = false;
        this.showCustomerReferenceFields = false;
        
        // Reset country selections
        this.country = 'IN';
        this.secondaryCountry = 'IN';
        this.phoneError = '';
        this.secondaryPhoneError = '';
    }
    
    displayToast(title, message, variant, recordId = null) {
        this.toastTitle = title;
        this.toastMessage = message;
        this.toastVariant = variant;
        this.showToast = true;
        this.duplicateRecordId = recordId; // Store for click handler
        
        // Auto hide after 5 seconds
        setTimeout(() => {
            this.closeToast();
        }, 5000);
    }
    
    closeToast() {
        this.showToast = false;
    }
    
    // Add a method to navigate to the record
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Customer__c',
                actionName: 'view'
            }
        });
    }
    
    handleSourceChange(event) {
        const value = event.target.value;
        this.customerData.customerSource = value;
        
        // Reset all reference fields
        this.showReferenceFields = false;
        this.showCustomerFields = false;
        this.showContractorFields = false;
        this.showMaisonFields = false;
        this.showSocialMediaPlatforms = false;
        this.showArchitectFields = false;
        
        // Reset all IDs and values
        this.customerData.referenceArchitect = '';
        this.customerData.customerId = '';
        this.customerData.contractorId = '';
        this.customerData.maisonId = '';
        this.customerData.socialMedia = '';
        this.customerData.referenceType = '';
        
        // Reset search terms
        this.architectSearchTerm = '';
        this.customerSearchTerm = '';
        this.contractorSearchTerm = '';
        this.maisonSearchTerm = '';
        
        if (value === 'Reference') {
            this.showReferenceFields = true;
        } else if (value === 'Social Media') {
            this.showSocialMediaPlatforms = true;
        }
    }

    handleReferenceTypeChange(event) {
        const value = event.target.value;
        this.customerData.referenceType = value;
        
        // Reset fields
        this.showCustomerReferenceFields = false;
        this.showReferralNameInput = false;
        this.showReferralPhoneField = false;
        this.showArchitectFields = false;
        this.customerData.referralName = '';
        this.customerData.phoneNumber = '';
        
        // Show appropriate fields based on selection
        if (value === 'Customer') {
            this.showCustomerReferenceFields = true;
        } else if (value === 'Architect' && this.customerData.customerSource === 'Reference') {
            this.showArchitectFields = true;
        } else if (['Contractor', 'Maison', 'Engineer', 'Plumber'].includes(value)) {
            this.showReferralPhoneField = true;
        }
    }

    handleReferralPhoneChange(event) {
        const phoneNumber = event.target.value;
        this.customerData.phoneNumber = phoneNumber;
        
        if (phoneNumber && phoneNumber.length >= 10) {
            checkReferralExists({ 
                phoneNumber: phoneNumber,
                referenceType: this.customerData.referenceType 
            })
                .then(result => {
                    this.referralExists = result.exists;
                    if (result.exists) {
                        this.referralName = result.name;
                        this.referralId = result.id;
                        this.showReferralNameInput = false;
                        this.displayToast('Info', `Existing ${this.customerData.referenceType} found: ${result.name}`, 'info');
                    } else {
                        this.showReferralNameInput = true;
                        this.displayToast('Info', `Please enter ${this.customerData.referenceType} name`, 'info');
                    }
                })
                .catch(error => {
                    console.error('Error checking referral:', error);
                    this.displayToast('Error', 'Error checking referral', 'error');
                });
        }
    }

    handleArchitectSearch(event) {
        const searchTerm = event.target.value;
        this.architectSearchTerm = searchTerm;
        
        if (searchTerm.length >= 2) {
            searchArchitects({ searchTerm: searchTerm })
                .then(results => {
                    this.architectSearchResults = results;
                    this.showArchitectResults = true;
                    this.showAddNewOption = true;
                })
                .catch(error => {
                    console.error('Error searching architects:', error);
                    this.displayToast('Error', 'Failed to search architects', 'error');
                });
        } else {
            this.showArchitectResults = false;
            this.showAddNewOption = false;
        }
    }

    selectArchitect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.architectSearchResults.find(arch => arch.Id === selectedId);
        if (selected) {
            console.log('Architect selected:', selected);
            this.architectSearchTerm = selected.Name;
            this.customerData.referenceArchitect = selected.Id;
            console.log('Architect ID set in customerData:', this.customerData.referenceArchitect);
            this.showArchitectResults = false;
        }
    }

    handleAddNewClick() {
        console.log('handleAddNewClick called');
        this.newArchitectData = {
            name: this.architectSearchTerm,
            phoneNumber: ''
        };
        this.showNewArchitectModal = true;
        this.showArchitectResults = false;
        console.log('Modal should be visible:', this.showNewArchitectModal);
    }

    handleNewArchitectInput(event) {
        const field = event.target.name;
        this.newArchitectData[field] = event.target.value;
        console.log('Architect input changed:', field, event.target.value);
    }

    createNewArchitect() {
        console.log('createNewArchitect called');
        console.log('newArchitectData:', this.newArchitectData);
        
        if (!this.newArchitectData.name) {
            this.displayToast('Error', 'Please enter Architect Name', 'error');
            return;
        }

        this.isLoading = true;
        console.log('Calling createArchitect with:', this.newArchitectData);
        
        createArchitect({ 
            name: this.newArchitectData.name,
            phoneNumber: this.newArchitectData.phoneNumber || ''
        })
            .then(result => {
                console.log('Architect created successfully:', result);
                // Set the architect ID in customer data
                this.customerData.referenceArchitect = result.Id;
                console.log('Architect ID set in customerData after creation:', this.customerData.referenceArchitect);
                // Set the search term to show the selected architect
                this.architectSearchTerm = result.Name;
                // Hide the search results
                this.showArchitectResults = false;
                // Close the modal
                this.closeNewArchitectModal();
                this.displayToast('Success', 'Architect created and linked successfully', 'success');
            })
            .catch(error => {
                console.error('Error creating architect:', error);
                let errorMessage = 'Failed to create architect';
                if (error.body && error.body.message) {
                    errorMessage += ': ' + error.body.message;
                } else if (error.message) {
                    errorMessage += ': ' + error.message;
                } else if (error.detail) {
                    errorMessage += ': ' + error.detail;
                }
                this.displayToast('Error', errorMessage, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeNewArchitectModal() {
        this.showNewArchitectModal = false;
        this.newArchitectData = { name: '', phoneNumber: '' };
    }

    // Customer search handling
    handleCustomerSearch(event) {
        const searchTerm = event.target.value;
        this.customerSearchTerm = searchTerm;
        
        // Reset results and states
        this.showCustomerResults = false;
        this.noCustomerResults = false;
        this.customerSearchResults = [];
        
        if (searchTerm.length >= 2) {
            this.isLoading = true;
            searchCustomers({ searchTerm: searchTerm })
                .then(results => {
                    this.customerSearchResults = results || [];
                    this.showCustomerResults = true;
                    this.noCustomerResults = !results || results.length === 0;
                    console.log('Search results:', results);
                })
                .catch(error => {
                    console.error('Error searching customers:', error);
                    this.displayToast('Error', 'Failed to search customers', 'error');
                    this.noCustomerResults = true;
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    selectCustomer(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.customerSearchResults.find(cust => cust.Id === selectedId);
        if (selected) {
            this.customerSearchTerm = `${selected.Name} - ${selected.Company}`;
            this.customerData.customerId = selected.Id;
            this.showCustomerResults = false;
        }
    }

    // Contractor handling
    handleContractorSearch(event) {
        const searchTerm = event.target.value;
        this.contractorSearchTerm = searchTerm;
        
        if (searchTerm.length >= 2) {
            searchContractors({ searchTerm: searchTerm })
                .then(results => {
                    this.contractorSearchResults = results;
                    this.showContractorResults = true;
                })
                .catch(error => {
                    console.error('Error searching contractors:', error);
                    this.displayToast('Error', 'Failed to search contractors', 'error');
                });
        } else {
            this.showContractorResults = false;
        }
    }

    selectContractor(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.contractorSearchResults.find(cont => cont.Id === selectedId);
        if (selected) {
            this.contractorSearchTerm = selected.Name;
            this.customerData.contractorId = selected.Id;
            this.showContractorResults = false;
        }
    }

    handleAddNewContractorClick() {
        this.newContractorData = {
            name: this.contractorSearchTerm
        };
        this.showNewContractorModal = true;
        this.showContractorResults = false;
    }

    handleNewContractorInput(event) {
        this.newContractorData.name = event.target.value;
    }

    createNewContractor() {
        if (!this.newContractorData.name) {
            this.displayToast('Error', 'Please enter Contractor Name', 'error');
            return;
        }

        this.isLoading = true;
        createContractor({ name: this.newContractorData.name })
            .then(result => {
                this.customerData.contractorId = result.Id;
                this.closeNewContractorModal();
                this.displayToast('Success', 'Contractor created successfully', 'success');
            })
            .catch(error => {
                this.displayToast('Error', 'Failed to create contractor: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeNewContractorModal() {
        this.showNewContractorModal = false;
        this.newContractorData = { name: '' };
    }

    // Maison handling
    handleMaisonSearch(event) {
        const searchTerm = event.target.value;
        this.maisonSearchTerm = searchTerm;
        
        if (searchTerm.length >= 2) {
            searchMaisons({ searchTerm: searchTerm })
                .then(results => {
                    this.maisonSearchResults = results;
                    this.showMaisonResults = true;
                })
                .catch(error => {
                    console.error('Error searching maisons:', error);
                    this.displayToast('Error', 'Failed to search maisons', 'error');
                });
        } else {
            this.showMaisonResults = false;
        }
    }

    selectMaison(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.maisonSearchResults.find(mais => mais.Id === selectedId);
        if (selected) {
            this.maisonSearchTerm = selected.Name;
            this.customerData.maisonId = selected.Id;
            this.showMaisonResults = false;
        }
    }

    handleAddNewMaisonClick() {
        this.newMaisonData = {
            name: this.maisonSearchTerm,
            company: ''
        };
        this.showNewMaisonModal = true;
        this.showMaisonResults = false;
    }

    handleNewMaisonInput(event) {
        this.newMaisonData.name = event.target.value;
    }

    createNewMaison() {
        if (!this.newMaisonData.name) {
            this.displayToast('Error', 'Please enter Maison Name', 'error');
            return;
        }

        this.isLoading = true;
        createMaison({ name: this.newMaisonData.name })
            .then(result => {
                this.customerData.maisonId = result.Id;
                this.closeNewMaisonModal();
                this.displayToast('Success', 'Maison created successfully', 'success');
            })
            .catch(error => {
                this.displayToast('Error', 'Failed to create maison: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeNewMaisonModal() {
        this.showNewMaisonModal = false;
        this.newMaisonData = { name: '' };
    }

    // Add this new method to handle state change
    handleStateChange(event) {
        const selectedState = event.target.value;
        this.customerData.state = selectedState;

        this.customerData.district = '';
        this.customerData.panchayat = '';
        if (selectedState) {
            this.showDistrictAndPanchayat = true;
            this.isPanchayatDisabled = this.panchayatOptions.length === 0;
        } else {
            this.showDistrictAndPanchayat = false;
            this.panchayatList = [];
            this.isPanchayatDisabled = true;
        }
    }

    handleDistrictChange(event) {
        const selectedDistrict = event.target.value;
        this.customerData.district = selectedDistrict;
        this.customerData.panchayat = '';
        this.panchayatSearchTerm = '';
        this.filteredPanchayatOptions = [];
        this.showPanchayatResults = false;
        if (selectedDistrict && this.panchayatOptionsStd.length > 0) {
            this.panchayatList = this.panchayatOptionsStd.map(p => ({ label: p, value: p }));
            this.isPanchayatDisabled = this.panchayatList.length === 0;
        } else {
            this.panchayatList = [];
            this.isPanchayatDisabled = true;
        }
    }

    handlePanchayatChange(event) {
        this.customerData.panchayat = event.target.value;
    }

    handleReferredPhoneChange(event) {
        const phoneNumber = event.target.value;
        this.customerData.phoneNumber = phoneNumber;
        
        if (phoneNumber && phoneNumber.length >= 10) {
            checkReferredCustomer({ phoneNumber: phoneNumber })
                .then(result => {
                    this.referredCustomerExists = result.exists;
                    if (result.exists) {
                        this.referredCustomerName = result.customerName;
                        this.showReferralNameInput = false;
                        this.displayToast('Info', `Existing customer found: ${result.customerName}`, 'info');
                    } else {
                        this.showReferralNameInput = true;
                        this.displayToast('Info', 'Please enter referral name', 'info');
                    }
                })
                .catch(error => {
                    console.error('Error checking referred customer:', error);
                    this.displayToast('Error', 'Error checking referred customer', 'error');
                });
        }
    }

    handleReferralNameChange(event) {
        const value = event.target.value.toUpperCase();
        this.customerData.referralName = value;
        event.target.value = value; // Update the input field value to uppercase
    }

    handleSocialMediaChange(event) {
        const platform = event.target.value;
        this.customerData.socialMedia = platform;
    }

    handleTypeChange(event) {
        const value = event.target.value;
        this.customerData.type = value;
        this.showPOCFields = value === 'Project';
    }

    handleToastClick() {
        if (this.duplicateRecordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.duplicateRecordId,
                    objectApiName: 'Customer__c',
                    actionName: 'view'
                }
            });
        }
    }

    handlePhoneInput(event) {
        const digits = event.target.value.replace(/[^0-9]/g, ''); // Only digits
        this.customerData.primaryPhone = digits; // Update the tracked field
        this.phoneError = '';
    }

    handleSecondaryPhoneInput(event) {
        const digits = event.target.value.replace(/[^0-9]/g, ''); // Only digits
        this.customerData.secondaryPhone = digits; // Update the tracked field
        this.secondaryPhoneError = '';
    }

    get countryList() {
        return this.countryOptionsStd.map((countryName) => ({
            code: countryName,
            name: countryName
        }));
    }

    handleCountryChange(event) {
        this.country = event.target.value;
        this.customerData.country = event.target.value;
        this.phoneError = '';
        this.phone = '';
    }

    get selectedCountryCode() {
        return '';
    }

    get selectedSecondaryCountryCode() {
        return '';
    }

    handleSecondaryCountryChange(event) {
        this.secondaryCountry = event.target.value;
        this.secondaryPhoneError = '';
        this.customerData.secondaryPhone = '';
    }

    handlePanchayatSearch(event) {
        this.panchayatSearchTerm = event.target.value;
        const allOptions = this.panchayatOptions;
        if (this.panchayatSearchTerm && allOptions.length > 0) {
            const search = this.panchayatSearchTerm.toLowerCase();
            this.filteredPanchayatOptions = allOptions.filter(p =>
                p.toLowerCase().includes(search)
            );
            this.showPanchayatResults = this.filteredPanchayatOptions.length > 0;
        } else {
            this.filteredPanchayatOptions = [];
            this.showPanchayatResults = false;
        }
        this.customerData.panchayat = this.panchayatSearchTerm;
    }

    selectPanchayat(event) {
        const value = event.currentTarget.dataset.value;
        this.panchayatSearchTerm = value;
        this.customerData.panchayat = value;
        this.showPanchayatResults = false;
    }
     
closeModal()
{
   this.dispatchToAura('Cancel',null);
}
    dispatchToAura(textMessage,leadId){
        // Created a custom event to Pass to aura component
        const event =  new CustomEvent('closepopup', {
            detail: {
                eventType: textMessage,
                Id:leadId,
            },
          });
          this.dispatchEvent(event);
    }
}