import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { TripService, Trip, CreateTripRequest, UpdateTripRequest } from '../../../services/trip.service';
import { NotificationService } from '../../../services/notification.service';

@Component({
  selector: 'app-trip-detail',
  templateUrl: './trip-detail.component.html',
  styleUrls: ['./trip-detail.component.scss']
})
export class TripDetailComponent implements OnInit {
  tripForm!: FormGroup;
  trip: Trip | null = null;
  isEditMode = false;
  isLoading = false;
  isSaving = false;
  tripId: number | null = null;
  
  // Image handling properties
  selectedFile: File | null = null;
  imagePreview: string | null = null;

  constructor(
    private fb: FormBuilder,
    private tripService: TripService,
    private route: ActivatedRoute,
    private router: Router,
    private notificationService: NotificationService
  ) { }

  ngOnInit(): void {
    this.initForm();

    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.tripId = +id;
      this.isEditMode = true;
      this.loadTrip(this.tripId);
    }
  }

  initForm(): void {
    this.tripForm = this.fb.group({
      title: ['', Validators.required],
      description: [''],
      startDate: [new Date().toISOString().split('T')[0], Validators.required],
      endDate: [null]
    });
  }

  loadTrip(id: number): void {
    this.isLoading = true;
    this.tripService.getTrip(id)
      .subscribe({
        next: (trip) => {
          this.trip = trip;
          this.tripForm.patchValue({
            title: trip.title,
            description: trip.description,
            startDate: this.formatDateForInput(trip.startDate),
            endDate: trip.endDate ? this.formatDateForInput(trip.endDate) : null
          });
          // Set image preview if trip has an image
          this.imagePreview = trip.tripImageBase64 ? 
            `data:image/jpeg;base64,${trip.tripImageBase64}` : null;
          this.isLoading = false;
        },
        error: (error) => {
          this.notificationService.showError(error.error?.message || 'Errore nel caricamento del viaggio');
          this.router.navigate(['/trips']);
          this.isLoading = false;
        }
      });
  }

  async saveTrip(): Promise<void> {
    console.log('button clicked');
    if (this.tripForm.invalid) {
      this.tripForm.markAllAsTouched();
      return;
    }

    this.isSaving = true;
    
    try {
      let tripImageBase64: string | undefined = undefined;
      
      // Convert file to base64 if a new image is selected
      if (this.selectedFile) {
        const fileBase64 = await this.convertFileToBase64(this.selectedFile);
        tripImageBase64 = fileBase64.split(',')[1]; // Remove data:image/jpeg;base64, prefix
      }

      const tripData = {
        title: this.tripForm.get('title')?.value,
        description: this.tripForm.get('description')?.value,
        destination: this.tripForm.get('destination')?.value,
        startDate: this.formatDate(this.tripForm.get('startDate')?.value),
        endDate: this.formatDate(this.tripForm.get('endDate')?.value),
        tripImageBase64: tripImageBase64 // Include image data
      };

      if (this.isEditMode && this.tripId) {
        this.tripService.updateTrip(this.tripId, tripData).subscribe({
          next: () => {
            this.notificationService.showSuccess('Viaggio aggiornato con successo');
            this.router.navigate(['/trips']);
            this.isSaving = false;
          },
          error: (error) => {
            this.notificationService.showError('Errore durante il salvataggio del viaggio');
            console.error('Error saving trip:', error);
            this.isSaving = false;
          }
        });
      } else {
        this.tripService.createTrip(tripData).subscribe({
          next: () => {
            this.notificationService.showSuccess('Viaggio creato con successo');
            this.router.navigate(['/trips']);
            this.isSaving = false;
          },
          error: (error) => {
            this.notificationService.showError('Errore durante il salvataggio del viaggio');
            console.error('Error saving trip:', error);
            this.isSaving = false;
          }
        });
      }
    } catch (error) {
      this.notificationService.showError('Errore durante il salvataggio del viaggio');
      console.error('Error saving trip:', error);
      this.isSaving = false;
    }
  }

  deleteTrip(): void {
    if (!this.tripId) return;

    if (confirm('Sei sicuro di voler eliminare questo viaggio? Questa azione non può essere annullata.')) {
      this.isLoading = true;
      this.tripService.deleteTrip(this.tripId)
        .subscribe({
          next: () => {
            this.notificationService.showSuccess('Viaggio eliminato con successo');
            this.router.navigate(['/trips']);
          },
          error: (error) => {
            this.notificationService.showError(error.error?.message || 'Errore nell\'eliminazione del viaggio');
            this.isLoading = false;
          }
        });
    }
  }

  copyShareCode(code: string): void {
    navigator.clipboard.writeText(code).then(() => {
      this.notificationService.showSuccess('Codice copiato negli appunti');
    });
  }

  onFileSelected(event: any): void {
    const file = event.target.files[0];
    if (file) {
      // Validate file type
      if (!file.type.startsWith('image/')) {
        this.notificationService.showError('Please select a valid image file');
        return;
      }
      
      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        this.notificationService.showError('Image size must be less than 5MB');
        return;
      }

      this.selectedFile = file;
      
      // Create preview
      const reader = new FileReader();
      reader.onload = (e) => {
        this.imagePreview = e.target?.result as string;
      };
      reader.readAsDataURL(file);
    }
  }

  removeImage(): void {
    this.selectedFile = null;
    this.imagePreview = null;
  }

  private async convertFileToBase64(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = error => reject(error);
    });
  }

  private formatDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toISOString().split('T')[0]; // Returns YYYY-MM-DD format
  }

  private formatDateForInput(dateString: string): string {
    const date = new Date(dateString);
    return date.toISOString().split('T')[0]; // Returns YYYY-MM-DD format
  }
}
