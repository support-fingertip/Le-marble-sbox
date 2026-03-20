import { LightningElement, api,wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ProjectsClientList extends NavigationMixin(LightningElement) {
    @api title = 'Projects and Clients';

    @track searchTerm = '';
    @track selectedCity = '';
    @track selectedStatus = '';
    @track selectedProjectType = '';
    @track fromDate = '';
    @track toDate = '';

    // Filter options
    cityOptions = [
        { label: 'All Cities', value: '' },
        { label: 'Chennai', value: 'Chennai' },
        { label: 'Coimbatore', value: 'Coimbatore' },
        { label: 'Madurai', value: 'Madurai' },
        { label: 'Kochi', value: 'Kochi' },
        { label: 'Thiruvananthapuram', value: 'Thiruvananthapuram' },
        { label: 'Kozhikode', value: 'Kozhikode' }
    ];

    statusOptions = [
        { label: 'All Status', value: '' },
        { label: 'Ongoing', value: 'Ongoing' },
        { label: 'Completed', value: 'Completed' },
        { label: 'Pending', value: 'Pending' }
    ];

    projectTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Residential', value: 'Residential' },
        { label: 'Commercial', value: 'Commercial' },
        { label: 'Industrial', value: 'Industrial' }
    ];

    // Sample client data
    @track clients = [
        {
            id: '1',
            name: 'Rajesh Kumar',
            type: 'Builder',
            contactPerson: 'Rajesh Kumar',
            lastVisit: '2024-03-15',
            nextFollowUp: '2024-03-20',
            status: 'Ongoing',
            statusClass: 'status-badge status-ongoing',
            city: 'Chennai',
            projectType: 'Residential'
        },
        {
            id: '2',
            name: 'Priya Menon',
            type: 'Architect',
            contactPerson: 'Priya Menon',
            lastVisit: '2024-03-14',
            nextFollowUp: '2024-03-18',
            status: 'Completed',
            statusClass: 'status-badge status-completed',
            city: 'Kochi',
            projectType: 'Commercial'
        },
        {
            id: '3',
            name: 'Suresh Pillai',
            type: 'Builder',
            contactPerson: 'Suresh Pillai',
            lastVisit: '2024-03-13',
            nextFollowUp: '2024-03-22',
            status: 'Pending',
            statusClass: 'status-badge status-pending',
            city: 'Thiruvananthapuram',
            projectType: 'Residential'
        },
        {
            id: '4',
            name: 'Anjali Nair',
            type: 'Architect',
            contactPerson: 'Anjali Nair',
            lastVisit: '2024-03-12',
            nextFollowUp: '2024-03-19',
            status: 'Ongoing',
            statusClass: 'status-badge status-ongoing',
            city: 'Coimbatore',
            projectType: 'Industrial'
        },
        {
            id: '5',
            name: 'Vijay Krishnan',
            type: 'Builder',
            contactPerson: 'Vijay Krishnan',
            lastVisit: '2024-03-11',
            nextFollowUp: '2024-03-21',
            status: 'Pending',
            statusClass: 'status-badge status-pending',
            city: 'Madurai',
            projectType: 'Residential'
        }
    ];

    // Computed property for filtered clients
    get filteredClients() {
        return this.clients.filter(client => {
            const matchesSearch = !this.searchTerm || 
                client.name.toLowerCase().includes(this.searchTerm.toLowerCase()) ||
                client.type.toLowerCase().includes(this.searchTerm.toLowerCase());
            
            const matchesCity = !this.selectedCity || client.city === this.selectedCity;
            const matchesStatus = !this.selectedStatus || client.status === this.selectedStatus;
            const matchesProjectType = !this.selectedProjectType || client.projectType === this.selectedProjectType;
            
            const matchesDateRange = (!this.fromDate || !this.toDate) || 
                (client.lastVisit >= this.fromDate && client.lastVisit <= this.toDate);

            return matchesSearch && matchesCity && matchesStatus && matchesProjectType && matchesDateRange;
        });
    }

    // Event handlers for filters
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleCityChange(event) {
        this.selectedCity = event.target.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

    handleProjectTypeChange(event) {
        this.selectedProjectType = event.target.value;
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
    }

    // Navigation handler
    handleViewDetails(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Client__c',
                actionName: 'view'
            }
        });
    }

    // Event handlers for navigation
    handleBackToDashboard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__appPage',
            attributes: {
                name: 'Projects_Dashboard'
            }
        });
    }
}