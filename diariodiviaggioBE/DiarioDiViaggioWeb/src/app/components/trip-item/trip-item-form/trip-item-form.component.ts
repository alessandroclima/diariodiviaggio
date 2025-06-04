import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatSnackBar } from '@angular/material/snack-bar';
import { CreateTripItemRequest, TripItem, TripItemService, UpdateTripItemRequest } from '../../../services/trip-item.service';

@Component({
  selector: 'app-trip-item-form',
  templateUrl: './trip-item-form.component.html',
  styleUrls: ['./trip-item-form.component.scss']
})
export class TripItemFormComponent implements OnInit {
  @Input() tripId: number = 0;
  @Input() tripItem?: TripItem | null = null;
  @Output() saved = new EventEmitter<TripItem>();
  @Output() cancelled = new EventEmitter<void>();

  tripItemForm!: FormGroup;
  selectedFile: File | null = null;
  imagePreview: string | ArrayBuffer | null = null;
  isEdit = false;
  isSubmitting = false;
  
  tripItemTypes = [
    { value: 'restaurant', label: 'Restaurant' },
    { value: 'hotel', label: 'Hotel' },
    { value: 'attraction', label: 'Attraction' },
    { value: 'note', label: 'Note' }
  ];

  constructor(
    private fb: FormBuilder, 
    private tripItemService: TripItemService,
    private snackBar: MatSnackBar
  ) { }

  ngOnInit(): void {
    this.isEdit = !!this.tripItem;

    this.tripItemForm = this.fb.group({
      title: [this.tripItem?.title || '', [Validators.required, Validators.maxLength(100)]],
      description: [this.tripItem?.description || ''],
      type: [this.tripItem?.type || 'note', [Validators.required]],
      location: [this.tripItem?.location || ''],
      rating: [this.tripItem?.rating || null]
    });

    if (this.isEdit && this.tripItem?.imageUrl) {
      this.imagePreview = this.tripItem.imageUrl;
    }
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length) {
      this.selectedFile = input.files[0];
      const reader = new FileReader();
      reader.onload = () => {
        this.imagePreview = reader.result;
      };
      reader.readAsDataURL(this.selectedFile);
    }
  }

  removeImage(): void {
    this.selectedFile = null;
    this.imagePreview = null;
  }

  onSubmit(): void {
    if (this.tripItemForm.invalid) {
      this.tripItemForm.markAllAsTouched();
      return;
    }

    this.isSubmitting = true;
    
    if (this.isEdit && this.tripItem) {
      this.updateTripItem();
    } else {
      this.createTripItem();
    }
  }

  private createTripItem(): void {
    const request: CreateTripItemRequest = {
      ...this.tripItemForm.value,
      image: this.selectedFile
    };
    
    this.tripItemService.createTripItem(this.tripId, request).subscribe({
      next: (result) => {
        this.isSubmitting = false;
        this.snackBar.open('Trip item created successfully', 'Close', { duration: 3000 });
        this.saved.emit(result);
      },
      error: (error) => {
        this.isSubmitting = false;
        this.snackBar.open('Failed to create trip item', 'Close', { duration: 3000 });
        console.error('Error creating trip item:', error);
      }
    });
  }

  private updateTripItem(): void {
    if (!this.tripItem) return;

    const request: UpdateTripItemRequest = {
      title: this.tripItemForm.value.title,
      description: this.tripItemForm.value.description,
      location: this.tripItemForm.value.location,
      rating: this.tripItemForm.value.rating
    };
    
    this.tripItemService.updateTripItem(this.tripItem.id, request).subscribe({
      next: (result) => {
        this.isSubmitting = false;
        this.snackBar.open('Trip item updated successfully', 'Close', { duration: 3000 });
        this.saved.emit(result);
      },
      error: (error) => {
        this.isSubmitting = false;
        this.snackBar.open('Failed to update trip item', 'Close', { duration: 3000 });
        console.error('Error updating trip item:', error);
      }
    });
  }

  onCancel(): void {
    this.cancelled.emit();
  }
}
