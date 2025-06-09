import { Component, Input, OnInit } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TripItem, TripItemService } from '../../../services/trip-item.service';
import { ConfirmDialogComponent } from '../../shared/confirm-dialog/confirm-dialog.component';

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
    private dialog: MatDialog,
    private snackBar: MatSnackBar
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
        this.snackBar.open('Failed to load trip items', 'Close', { duration: 3000 });
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
    const dialogRef = this.dialog.open(ConfirmDialogComponent, {
      width: '350px',
      data: {
        title: 'Delete Entry',
        message: `Are you sure you want to delete "${item.title}"?`,
        confirmButtonText: 'Delete'
      }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.tripItemService.deleteTripItem(item.id).subscribe({
          next: () => {
            this.tripItems = this.tripItems.filter(i => i.id !== item.id);
            this.snackBar.open('Entry deleted successfully', 'Close', { duration: 3000 });
          },
          error: (err) => {
            console.error('Error deleting trip item:', err);
            this.snackBar.open('Failed to delete entry', 'Close', { duration: 3000 });
          }
        });
      }
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
      case 'restaurant': return 'restaurant';
      case 'hotel': return 'hotel';
      case 'attraction': return 'attractions';
      case 'note': return 'note';
      default: return 'article';
    }
  }

  getFormattedDate(dateStr: string): string {
    const date = new Date(dateStr);
    return date.toLocaleDateString();
  }
}
