import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ProjectsKeyAccountDashboard extends NavigationMixin(LightningElement) {
    @api title = 'Projects Dashboard';
    
    // Summary Metrics
    @track totalBuilders = 12;
    @track totalArchitects = 8;
    @track ongoingProjects = 15;
    @track followUpsDueToday = 5;

    // Recent Interactions Data
    @track recentInteractions = [
        {
            id: '1',
            clientName: 'Rajesh Kumar',
            type: 'Builder',
            lastVisit: '2024-03-15',
            nextFollowUp: '2024-03-20',
            status: 'Pending',
            statusClass: 'status-badge status-pending'
        },
        {
            id: '2',
            clientName: 'Priya Menon',
            type: 'Architect',
            lastVisit: '2024-03-14',
            nextFollowUp: '2024-03-18',
            status: 'Completed',
            statusClass: 'status-badge status-completed'
        },
        {
            id: '3',
            clientName: 'Suresh Pillai',
            type: 'Builder',
            lastVisit: '2024-03-13',
            nextFollowUp: '2024-03-22',
            status: 'Pending',
            statusClass: 'status-badge status-pending'
        },
        {
            id: '4',
            clientName: 'Anjali Nair',
            type: 'Architect',
            lastVisit: '2024-03-12',
            nextFollowUp: '2024-03-19',
            status: 'Completed',
            statusClass: 'status-badge status-completed'
        },
        {
            id: '5',
            clientName: 'Vijay Krishnan',
            type: 'Builder',
            lastVisit: '2024-03-11',
            nextFollowUp: '2024-03-21',
            status: 'Pending',
            statusClass: 'status-badge status-pending'
        }
    ];

    // Upcoming Site Visits Data
    @track upcomingVisits = [
        {
            id: '1',
            day: '18',
            month: 'MAR',
            clientName: 'Meera Iyer',
            location: 'Chennai, Tamil Nadu',
            time: '10:00 AM'
        },
        {
            id: '2',
            day: '19',
            month: 'MAR',
            clientName: 'Arun Kumar',
            location: 'Kochi, Kerala',
            time: '2:30 PM'
        },
        {
            id: '3',
            day: '20',
            month: 'MAR',
            clientName: 'Lakshmi Menon',
            location: 'Thiruvananthapuram, Kerala',
            time: '11:00 AM'
        },
        {
            id: '4',
            day: '21',
            month: 'MAR',
            clientName: 'Ravi Shankar',
            location: 'Coimbatore, Tamil Nadu',
            time: '3:00 PM'
        }
    ];

    // Event Handlers
    handleNewSiteVisit() {
        // Navigate to new site visit page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: 'new',
                objectApiName: 'Site_Visit__c',
                actionName: 'new'
            }
        });
    }

    handleNewFollowUp() {
        // Navigate to new follow-up page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: 'new',
                objectApiName: 'Follow_Up__c',
                actionName: 'new'
            }
        });
    }

    handleViewAllInteractions() {
        // Navigate to all interactions list view
        this[NavigationMixin.Navigate]({
            type: 'standard__listView',
            attributes: {
                objectApiName: 'Interaction__c',
                actionName: 'viewall'
            }
        });
    }

    handleViewCalendar() {
        // Navigate to calendar view
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: 'calendar',
                objectApiName: 'Site_Visit__c',
                actionName: 'view'
            }
        });
    }

    handleViewDetails(event) {
        const recordId = event.currentTarget.dataset.id;
        // Navigate to interaction detail page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Interaction__c',
                actionName: 'view'
            }
        });
    }

    handleVisitClick(event) {
        const recordId = event.currentTarget.dataset.id;
        // Navigate to site visit detail page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Site_Visit__c',
                actionName: 'view'
            }
        });
    }

    handleViewAllClients() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/lightning/c/__projectsClientList'
            }
        });
    }
}