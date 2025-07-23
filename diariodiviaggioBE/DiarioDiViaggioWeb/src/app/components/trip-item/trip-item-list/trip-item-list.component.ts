import { Component, Input, OnInit } from '@angular/core';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { TripItem, TripItemService } from '../../../services/trip-item.service';
import { ConfirmDialogComponent } from '../../shared/confirm-dialog/confirm-dialog.component';
import { NotificationService } from '../../../services/notification.service';

@Component({
  selector: 'app-trip-item-list',
  templateUrl: './trip-item-list.component.html',
  styleUrls: ['./trip-item-list.component.scss']
})
export class TripItemListComponent implements OnInit {
  @Input('tripId') tripId!: number;
  
  tripItems: TripItem[] = [];
  loading = true;
  error = false;
  
  showAddForm = false;
  editingItem: TripItem | null = null;
  
  activeFilters: { [key: string]: boolean } = {
    restaurant: true,
    hotel: true,
    attraction: true,
    note: true
  };

  constructor(
    private tripItemService: TripItemService,
    private modal: NgbModal,
    private notificationService: NotificationService
  ) { }

  ngOnInit(): void {
    console.log('TripItemListComponent initialized with tripId:', this.tripId);
    this.loadTripItems();
  }

  loadTripItems(): void {
    this.loading = true;
    this.error = false;
    
    this.tripItemService.getTripItems(this.tripId).subscribe({
      next: (items) => {
        this.tripItems = items;
        this.loading = false;
      },
      error: (err) => {
        console.error('Error loading trip items:', err);
        this.loading = false;
        this.error = true;
        this.notificationService.showError('Failed to load trip items');
      }
    });
  }

  openAddForm(): void {
    this.showAddForm = true;
    this.editingItem = null;
  }

  closeForm(): void {
    this.showAddForm = false;
    this.editingItem = null;
  }

  onSaveItem(item: TripItem): void {
    if (this.editingItem) {
      // Replace the edited item in the array
      const index = this.tripItems.findIndex(i => i.id === item.id);
      if (index !== -1) {
        this.tripItems[index] = item;
      }
    } else {
      // Add new item to the array
      this.tripItems.unshift(item);
    }
    
    this.closeForm();
  }

  editItem(item: TripItem): void {
    this.editingItem = item;
    this.showAddForm = true;
  }

  deleteItem(item: TripItem): void {
    const modalRef = this.modal.open(ConfirmDialogComponent);
    modalRef.componentInstance.title = 'Delete Entry';
    modalRef.componentInstance.message = `Are you sure you want to delete "${item.title}"?`;
    modalRef.componentInstance.confirmButtonText = 'Delete';

    modalRef.result.then((result: boolean) => {
      if (result) {
        this.tripItemService.deleteTripItem(item.id).subscribe({
          next: () => {
            this.tripItems = this.tripItems.filter(i => i.id !== item.id);
            this.notificationService.showSuccess('Entry deleted successfully');
          },
          error: (err) => {
            console.error('Error deleting trip item:', err);
            this.notificationService.showError('Failed to delete entry');
          }
        });
      }
    }).catch(() => {
      // Modal dismissed
    });
  }

  toggleFilter(type: string): void {
    this.activeFilters[type] = !this.activeFilters[type];
  }

  isItemVisible(item: TripItem): boolean {
    return this.activeFilters[item.type];
  }

  getFilteredItems(): TripItem[] {
    return this.tripItems.filter(item => this.isItemVisible(item));
  }

  getTypeIcon(type: string): string {
    switch (type) {
      case 'restaurant': return 'bi-shop';
      case 'hotel': return 'bi-house';
      case 'attraction': return 'bi-geo-alt';
      case 'note': return 'bi-sticky';
      default: return 'bi-file-text';
    }
  }

  getFormattedDate(dateStr: string): string {
    const date = new Date(dateStr);
    return date.toLocaleDateString();
  }
}
