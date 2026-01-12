import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFinanceTransactions from '@salesforce/apex/FinanceTransactionController.getFinanceTransactions';
import updatePaymentStatus from '@salesforce/apex/FinanceTransactionController.updatePaymentStatus';
import updateTransactionReference from '@salesforce/apex/FinanceTransactionController.updateTransactionReference';
import updateDueDate from '@salesforce/apex/FinanceTransactionController.updateDueDate';
import getPaymentTypeOptions from '@salesforce/apex/FinanceTransactionController.getPaymentTypeOptions';
import getPaymentStatusOptions from '@salesforce/apex/FinanceTransactionController.getPaymentStatusOptions';
import { NavigationMixin } from 'lightning/navigation';

const PAGE_SIZE = 10;

export default class FinanceTransactionList extends NavigationMixin(LightningElement) {
    @track allTransactions = [];
    @track transactions = [];
    @track isLoading = false;
    @track selectedTransaction = null;
    @track showEditModal = false;
    @track showStatusModal = false;
    @track newStatus = '';
    @track newReference = '';
    @track newDueDate = '';
    @track paymentTypeOptions = [];
    @track paymentStatusOptions = [];
    @track selectedPaymentType = '';
    @track selectedPaymentStatus = '';
    @track currentPage = 1;
    @track dueDateFrom = '';
    @track dueDateTo = '';
    @track filterYear = '';
    @track filterMonth = '';
    @track filterDay = '';

    @wire(getFinanceTransactions)
    wiredTransactions({ error, data }) {
        if (data) {
            this.allTransactions = data;
            this.transactions = this.getFilteredTransactions().slice(0, PAGE_SIZE);
        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    connectedCallback() {
        getPaymentTypeOptions().then(result => {
            this.paymentTypeOptions = [
                { label: 'Select an Option', value: '' },
                ...result.map(opt => ({ label: opt.label, value: opt.value }))
            ];
        });
        getPaymentStatusOptions().then(result => {
            this.paymentStatusOptions = [
                { label: 'Select an Option', value: '' },
                ...result.map(opt => ({ label: opt.label, value: opt.value }))
            ];
        });
    }

    handlePaymentTypeChange(event) {
        this.selectedPaymentType = event.detail.value;
        this.currentPage = 1;
        this.updateTransactions();
    }

    handlePaymentStatusChange(event) {
        this.selectedPaymentStatus = event.detail.value;
        this.currentPage = 1;
        this.updateTransactions();
    }

    handleDueDateFromChange(event) {
        this.dueDateFrom = event.detail.value;
        this.currentPage = 1;
        this.updateTransactions();
    }

    handleDueDateToChange(event) {
        this.dueDateTo = event.detail.value;
        this.currentPage = 1;
        this.updateTransactions();
    }

    handleYearChange(event) {
        this.filterYear = event.detail.value;
        this.filterMonth = '';
        this.filterDay = '';
    }

    handleMonthChange(event) {
        this.filterMonth = event.detail.value;
        this.filterDay = '';
    }

    handleDayChange(event) {
        this.filterDay = event.detail.value;
    }

    updateTransactions() {
        const filtered = this.getFilteredTransactions();
        this.transactions = filtered.slice(0, this.currentPage * PAGE_SIZE);
    }

    getFilteredTransactions() {
        return this.allTransactions.filter(txn => {
            let matchType = true;
            let matchStatus = true;
            let matchDueFrom = true;
            let matchDueTo = true;
            if (this.selectedPaymentType) {
                matchType = txn.Payment_Type__c === this.selectedPaymentType;
            }
            if (this.selectedPaymentStatus) {
                matchStatus = txn.Payment_Status__c === this.selectedPaymentStatus;
            }
            if (this.dueDateFrom) {
                matchDueFrom = txn.Due_Date__c && txn.Due_Date__c >= this.dueDateFrom;
            }
            if (this.dueDateTo) {
                matchDueTo = txn.Due_Date__c && txn.Due_Date__c <= this.dueDateTo;
            }
            return matchType && matchStatus && matchDueFrom && matchDueTo;
        });
    }

    filterByCardDate(txn) {
        // Use Payment_Date__c for card filtering
        if (!txn.Payment_Date__c) return false;
        const date = new Date(txn.Payment_Date__c);
        if (this.filterYear && date.getFullYear().toString() !== this.filterYear) return false;
        if (this.filterMonth && (date.getMonth() + 1).toString().padStart(2, '0') !== this.filterMonth) return false;
        if (this.filterDay && date.getDate().toString().padStart(2, '0') !== this.filterDay) return false;
        return true;
    }

    get totalReceived() {
        return this.allTransactions
            .filter(txn => txn.Payment_Status__c === 'Received' && this.filterByCardDate(txn))
            .reduce((sum, txn) => sum + (txn.Amount__c ? parseFloat(txn.Amount__c) : 0), 0);
    }

    get overdueAmount() {
        return this.allTransactions
            .filter(txn => txn.Payment_Status__c === 'Overdue' && this.filterByCardDate(txn))
            .reduce((sum, txn) => sum + (txn.Amount__c ? parseFloat(txn.Amount__c) : 0), 0);
    }

    get appliedToday() {
        return this.allTransactions
            .filter(txn => txn.Payment_Status__c === 'Applied' && this.filterByCardDate(txn))
            .reduce((sum, txn) => sum + (txn.Amount__c ? parseFloat(txn.Amount__c) : 0), 0);
    }

    get notReceivedAmount() {
        return this.allTransactions
            .filter(txn => txn.Payment_Status__c === 'Not Received' && this.filterByCardDate(txn))
            .reduce((sum, txn) => sum + (txn.Amount__c ? parseFloat(txn.Amount__c) : 0), 0);
    }

    get yearOptions() {
        // Get unique years from Payment_Date__c
        const years = Array.from(new Set(this.allTransactions
            .filter(txn => txn.Payment_Date__c)
            .map(txn => new Date(txn.Payment_Date__c).getFullYear().toString())));
        years.sort((a, b) => b - a);
        return [{ label: 'Select Year', value: '' }, ...years.map(y => ({ label: y, value: y }))];
    }

    get monthOptions() {
        if (!this.filterYear) return [{ label: 'Select Month', value: '' }];
        const months = Array.from(new Set(this.allTransactions
            .filter(txn => txn.Payment_Date__c && new Date(txn.Payment_Date__c).getFullYear().toString() === this.filterYear)
            .map(txn => (new Date(txn.Payment_Date__c).getMonth() + 1).toString().padStart(2, '0'))));
        months.sort();
        return [{ label: 'Select Month', value: '' }, ...months.map(m => ({ label: m, value: m }))];
    }

    get dayOptions() {
        if (!this.filterYear || !this.filterMonth) return [{ label: 'Select Date', value: '' }];
        const days = Array.from(new Set(this.allTransactions
            .filter(txn => {
                if (!txn.Payment_Date__c) return false;
                const d = new Date(txn.Payment_Date__c);
                return d.getFullYear().toString() === this.filterYear && (d.getMonth() + 1).toString().padStart(2, '0') === this.filterMonth;
            })
            .map(txn => new Date(txn.Payment_Date__c).getDate().toString().padStart(2, '0'))));
        days.sort();
        return [{ label: 'Select Date', value: '' }, ...days.map(d => ({ label: d, value: d }))];
    }

    handleShowMore() {
        this.currentPage++;
        this.updateTransactions();
    }

    get canShowMore() {
        return this.getFilteredTransactions().length > this.transactions.length;
    }

    handleTransactionClick(event) {
        const recordId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Payment__c',
                actionName: 'view'
            }
        });
    }

    handleReferenceChange(event) {
        this.selectedTransaction = event.target.dataset.id;
        this.newReference = event.target.value;
        this.showEditModal = true;
    }

    handleDueDateChange(event) {
        this.selectedTransaction = event.target.dataset.id;
        this.newDueDate = event.target.value;
        this.showEditModal = true;
    }

    async handleUpdateReference() {
        try {
            await updateTransactionReference({
                paymentId: this.selectedTransaction,
                docEntry: this.newReference
            });
            this.showToast('Success', 'Document entry updated successfully', 'success');
            this.showEditModal = false;
            this.refreshTransactions();
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    async handleUpdateDueDate() {
        try {
            await updateDueDate({
                paymentId: this.selectedTransaction,
                newDueDate: this.newDueDate
            });
            this.showToast('Success', 'Due date updated successfully', 'success');
            this.showEditModal = false;
            this.refreshTransactions();
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    async refreshTransactions() {
        this.isLoading = true;
        try {
            const result = await getFinanceTransactions();
            this.allTransactions = result;
            this.currentPage = 1;
            this.updateTransactions();
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        if (isNaN(d)) return dateStr;
        const day = d.getDate().toString().padStart(2, '0');
        const month = (d.getMonth() + 1).toString().padStart(2, '0');
        const year = d.getFullYear();
        return `${day}-${month}-${year}`;
    }

    get transactionsWithFormattedDates() {
        return this.transactions.map(txn => {
            return {
                ...txn,
                formattedDueDate: this.formatDate(txn.Due_Date__c),
                formattedPaymentDate: this.formatDate(txn.Payment_Date__c)
            };
        });
    }
}