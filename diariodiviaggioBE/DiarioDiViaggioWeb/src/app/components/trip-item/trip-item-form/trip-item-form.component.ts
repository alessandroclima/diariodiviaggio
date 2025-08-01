import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { CreateTripItemRequest, TripItem, TripItemService, UpdateTripItemRequest } from '../../../services/trip-item.service';
import { ActivatedRoute, Router } from '@angular/router';
import { NotificationService } from '../../../services/notification.service';

@Component({
  selector: 'app-trip-item-form',
  templateUrl: './trip-item-form.component.html',
  styleUrls: ['./trip-item-form.component.scss']
})
export class TripItemFormComponent implements OnInit {
  @Input('tripId') tripId: number = 0;
  @Input() tripItem?: TripItem | null = null;
  @Output() saved = new EventEmitter<TripItem>();
  @Output() cancelled = new EventEmitter<void>();

  tripItemForm!: FormGroup;
  selectedFile: File | null = null;
  imagePreview: string | ArrayBuffer | null = null;
  imageRemoved = false;
  isEdit = false;
  isSubmitting = false;
  
  tripItemTypes = [
    { value: 'Restaurant', label: 'Restaurant' },
    { value: 'Hotel', label: 'Hotel' },
    { value: 'Attraction', label: 'Attraction' },
    { value: 'Note', label: 'Notes' }
  ];

  constructor(
    private fb: FormBuilder, 
    private tripItemService: TripItemService,
    private notificationService: NotificationService,
    private route: ActivatedRoute,
    private router: Router
  ) { }

  ngOnInit(): void {
    this.route.paramMap.subscribe(params => {
      // Parse tripId from route parameters
      const tripIdParam = params.get('tripId');
      if (tripIdParam) {
        this.tripId = parseInt(tripIdParam, 10);
      }

      // Check if we're in edit mode by looking for an item ID
      const itemIdParam = params.get('id');
      if (itemIdParam) {
        this.isEdit = true;
        this.loadTripItem(parseInt(itemIdParam, 10));
      } else {
        this.isEdit = false;
        this.initializeForm();
      }
    });
  }

  private loadTripItem(itemId: number): void {
    this.tripItemService.getTripItem(itemId).subscribe({
      next: (item) => {
        this.tripItem = item;
        console.log('Loaded trip item:', item);
        this.initializeForm();
        if (this.tripItem?.imageUrl) {
          this.imagePreview = 'data:image/jpeg;base64,' + this.tripItem.imageUrl;
        }
      },
      error: (error) => {
        console.error('Error loading trip item:', error);
        this.notificationService.showError('Failed to load trip item');
        this.router.navigate(['/trips', this.tripId, 'items']);
      }
    });
  }

  private initializeForm(): void {
    this.tripItemForm = this.fb.group({
      title: [this.tripItem?.title || '', [Validators.required, Validators.maxLength(100)]],
      description: [this.tripItem?.description || ''],
      type: [this.tripItem?.type?.toLowerCase() || 'note', [Validators.required]],
      location: [this.tripItem?.location || ''],
      rating: [this.tripItem?.rating || null]
    });
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length) {
      this.selectedFile = input.files[0];
      this.imageRemoved = false;
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
    this.imageRemoved = true;
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
        this.notificationService.showSuccess('Trip item created successfully');
        this.router.navigate(['/trips', this.tripId, 'items']);
      },
      error: (error) => {
        this.isSubmitting = false;
        this.notificationService.showError('Failed to create trip item');
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
      rating: this.tripItemForm.value.rating,
      image: this.selectedFile || undefined,
      removeImage: this.imageRemoved
    };
    
    this.tripItemService.updateTripItem(this.tripItem.id, request).subscribe({
      next: (result) => {
        this.isSubmitting = false;
        this.notificationService.showSuccess('Trip item updated successfully');
        this.router.navigate(['/trips', this.tripId, 'items']);
      },
      error: (error) => {
        this.isSubmitting = false;
        this.notificationService.showError('Failed to update trip item');
        console.error('Error updating trip item:', error);
      }
    });
  }

  onCancel(): void {
    this.router.navigate(['/trips', this.tripId, 'items']);
  }
}
