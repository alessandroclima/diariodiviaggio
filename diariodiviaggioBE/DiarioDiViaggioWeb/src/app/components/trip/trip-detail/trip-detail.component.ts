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
          this.isLoading = false;
        },
        error: (error) => {
          this.notificationService.showError(error.error?.message || 'Errore nel caricamento del viaggio');
          this.router.navigate(['/trips']);
          this.isLoading = false;
        }
      });
  }

  saveTrip(): void {
    if (this.tripForm.invalid) return;
    console.log('Saving trip:', this.tripForm.value);
    this.isSaving = true;

    if (this.isEditMode && this.tripId) {
      const updateRequest: UpdateTripRequest = {
        ...this.tripForm.value,
        startDate: this.formatDate(new Date(this.tripForm.value.startDate)),
        endDate: this.tripForm.value.endDate ? this.formatDate(new Date(this.tripForm.value.endDate)) : undefined
      };

      this.tripService.updateTrip(this.tripId, updateRequest)
        .subscribe({
          next: () => {
            this.notificationService.showSuccess('Viaggio aggiornato con successo');
            this.isSaving = false;
          },
          error: (error) => {
            this.notificationService.showError(error.error?.message || 'Errore nell\'aggiornamento del viaggio');
            this.isSaving = false;
          }
        });
    } else {
      const createRequest: CreateTripRequest = {
        ...this.tripForm.value,
        startDate: this.formatDate(this.tripForm.value.startDate),
        endDate: this.tripForm.value.endDate ? this.formatDate(this.tripForm.value.endDate) : undefined
      };

      this.tripService.createTrip(createRequest)
        .subscribe({
          next: (trip) => {
            this.notificationService.showSuccess('Viaggio creato con successo');
            this.router.navigate(['/trips', trip.id]);
            this.isSaving = false;
          },
          error: (error) => {
            this.notificationService.showError(error.error?.message || 'Errore nella creazione del viaggio');
            this.isSaving = false;
          }
        });
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

  private formatDate(date: Date): string {
    return date.toISOString();
  }

  private formatDateForInput(dateString: string): string {
    const date = new Date(dateString);
    return date.toISOString().split('T')[0]; // Returns YYYY-MM-DD format
  }
}
