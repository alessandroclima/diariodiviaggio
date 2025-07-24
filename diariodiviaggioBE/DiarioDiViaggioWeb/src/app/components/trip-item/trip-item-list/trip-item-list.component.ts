import { Component, Input, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
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
  tripId!: number;
  
  tripItems: TripItem[] = [];
  loading = true;
  error = false;
  
  showAddForm = false;
  editingItem: TripItem | null = null;
  
  activeFilters: { [key: string]: boolean } = {
    Restaurant: true,
    Hotel: true,
    Attraction: true,
    Note: true
  };

  constructor(
    private route: ActivatedRoute,
    private tripItemService: TripItemService,
    private modal: NgbModal,
    private notificationService: NotificationService
  ) { }

  ngOnInit(): void {
    // Get tripId from route params instead of @Input
    const tripIdParam = this.route.snapshot.paramMap.get('tripId');
    if (tripIdParam) {
      this.tripId = +tripIdParam;
      console.log('TripItemListComponent initialized with tripId from route:', this.tripId);
      this.loadTripItems();
    } else {
      console.error('No tripId found in route params');
      this.error = true;
      this.loading = false;
    }
  }

  loadTripItems(): void {
    this.loading = true;
    this.error = false;
    
    this.tripItemService.getTripItems(this.tripId).subscribe({
      next: (items) => {
        console.log('Loaded trip items:', items);
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
    const visible = this.activeFilters[item.type];
    console.log(`isItemVisible - item.type: ${item.type}, activeFilters[${item.type}]: ${visible}`);
    return visible;
  }

  getFilteredItems(): TripItem[] {
    console.log('getFilteredItems called');
    console.log('tripItems:', this.tripItems);
    console.log('activeFilters:', this.activeFilters);
    
    const filtered = this.tripItems.filter(item => {
      console.log(`Item: ${item.title}, Type: ${item.type}, Visible: ${this.isItemVisible(item)}`);
      return this.isItemVisible(item);
    });
    
    console.log('Filtered items:', filtered);
    return filtered;
  }

  getTypeIcon(type: string): string {
    switch (type) {
      case 'Restaurant': return 'bi-shop';
      case 'Hotel': return 'bi-house';
      case 'Attraction': return 'bi-geo-alt';
      case 'Note': return 'bi-sticky';
      default: return 'bi-file-text';
    }
  }

  getFormattedDate(dateStr: string): string {
    const date = new Date(dateStr);
    return date.toLocaleDateString();
  }
}
