import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { LuggageService, Luggage, LuggageItem, CreateLuggageItemRequest, UpdateLuggageItemRequest } from '../../../services/luggage.service';
import { NotificationService } from '../../../services/notification.service';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ConfirmDialogComponent } from '../../shared/confirm-dialog/confirm-dialog.component';

@Component({
  selector: 'app-luggage-detail',
  templateUrl: './luggage-detail.component.html',
  styleUrls: ['./luggage-detail.component.scss']
})
export class LuggageDetailComponent implements OnInit {
  Math = Math;
  luggage: Luggage | null = null;
  isLoading = false;
  isSaving = false;
  showAddForm = false;
  editingItem: LuggageItem | null = null;
  
  // Simple form fields
  itemName = '';
  itemNotes = '';
  itemQuantity = 1;
  
  tripId!: number;
  luggageId!: number;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private luggageService: LuggageService,
    private notificationService: NotificationService,
    private modal: NgbModal
  ) {}

  ngOnInit(): void {
    const tripId = this.route.snapshot.paramMap.get('tripId');
    const luggageId = this.route.snapshot.paramMap.get('luggageId');
    
    if (tripId && luggageId) {
      this.tripId = +tripId;
      this.luggageId = +luggageId;
      this.loadLuggage();
    } else {
      this.router.navigate(['/trips']);
    }
  }

  loadLuggage(): void {
    this.isLoading = true;
    this.luggageService.getLuggage(this.luggageId)
      .subscribe({
        next: (luggage) => {
          this.luggage = luggage;
          this.isLoading = false;
        },
        error: (error) => {
          this.notificationService.showError(error.error?.message || 'Error loading luggage');
          this.router.navigate(['/trips', this.tripId, 'luggage']);
          this.isLoading = false;
        }
      });
  }

  toggleAddForm(): void {
    this.showAddForm = !this.showAddForm;
    this.editingItem = null;
    this.itemName = '';
    this.itemNotes = '';
    this.itemQuantity = 1;
  }

  editItem(item: LuggageItem): void {
    this.editingItem = item;
    this.showAddForm = true;
    this.itemName = item.name;
    this.itemNotes = item.notes || '';
    this.itemQuantity = item.quantity;
  }

  saveItem(): void {
    if (!this.itemName.trim()) {
      this.notificationService.showError('Item name is required');
      return;
    }

    this.isSaving = true;

    if (this.editingItem) {
      // Update existing item
      const updateRequest: UpdateLuggageItemRequest = {
        name: this.itemName,
        notes: this.itemNotes,
        quantity: this.itemQuantity,
        isPacked: this.editingItem.isPacked
      };

      this.luggageService.updateLuggageItem(this.editingItem.id, updateRequest)
        .subscribe({
          next: () => {
            this.notificationService.showSuccess('Item updated successfully');
            this.loadLuggage();
            this.toggleAddForm();
            this.isSaving = false;
          },
          error: (error) => {
            this.notificationService.showError(error.error?.message || 'Error updating item');
            this.isSaving = false;
          }
        });
    } else {
      // Create new item
      const createRequest: CreateLuggageItemRequest = {
        name: this.itemName,
        notes: this.itemNotes,
        quantity: this.itemQuantity
      };

      this.luggageService.addLuggageItem(this.luggageId, createRequest)
        .subscribe({
          next: () => {
            this.notificationService.showSuccess('Item added successfully');
            this.loadLuggage();
            this.toggleAddForm();
            this.isSaving = false;
          },
          error: (error) => {
            this.notificationService.showError(error.error?.message || 'Error adding item');
            this.isSaving = false;
          }
        });
    }
  }

  toggleItemPacked(item: LuggageItem): void {
    const updateRequest: UpdateLuggageItemRequest = {
      name: item.name,
      notes: item.notes,
      quantity: item.quantity,
      isPacked: !item.isPacked
    };

    this.luggageService.updateLuggageItem(item.id, updateRequest)
      .subscribe({
        next: () => {
          item.isPacked = !item.isPacked;
          this.notificationService.showSuccess(
            item.isPacked ? 'Item marked as packed' : 'Item marked as unpacked'
          );
        },
        error: (error) => {
          this.notificationService.showError(error.error?.message || 'Error updating item');
        }
      });
  }

  deleteItem(item: LuggageItem): void {
    const modalRef = this.modal.open(ConfirmDialogComponent);
    modalRef.componentInstance.title = 'Delete Item';
    modalRef.componentInstance.message = `Are you sure you want to delete "${item.name}"?`;
    modalRef.componentInstance.confirmText = 'Delete';
    modalRef.componentInstance.confirmClass = 'btn-danger';

    modalRef.result.then((confirmed) => {
      if (confirmed) {
        this.luggageService.deleteLuggageItem(item.id)
          .subscribe({
            next: () => {
              this.notificationService.showSuccess('Item deleted successfully');
              this.loadLuggage();
            },
            error: (error) => {
              this.notificationService.showError(error.error?.message || 'Error deleting item');
            }
          });
      }
    }).catch(() => {
      // Modal dismissed
    });
  }

  getPackedItemsCount(): number {
    if (!this.luggage?.items) return 0;
    return this.luggage.items.filter(item => item.isPacked).length;
  }

  getPackingProgress(): number {
    if (!this.luggage?.items || this.luggage.items.length === 0) return 0;
    return (this.getPackedItemsCount() / this.luggage.items.length) * 100;
  }

  goBack(): void {
    this.router.navigate(['/trips', this.tripId, 'luggage']);
  }
}
