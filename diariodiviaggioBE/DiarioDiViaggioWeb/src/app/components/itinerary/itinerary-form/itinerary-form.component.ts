import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { ItineraryService, CreateItineraryDto, UpdateItineraryDto, ItineraryDto, ItineraryActivityType, ItineraryTimeSlot } from '../../../services/itinerary.service';

@Component({
  selector: 'app-itinerary-form',
  templateUrl: './itinerary-form.component.html',
  styleUrls: ['./itinerary-form.component.scss']
})
export class ItineraryFormComponent implements OnInit {
  activityForm: FormGroup;
  tripId!: number;
  activityId?: number;
  isEditMode = false;
  isLoading = false;
  isSaving = false;
  error: string | null = null;
  activityTypes = this.itineraryService.getActivityTypeOptions();
  timeSlots = this.itineraryService.getTimeSlotOptions();

  constructor(
    private fb: FormBuilder,
    private route: ActivatedRoute,
    private router: Router,
    private itineraryService: ItineraryService
  ) {
    this.activityForm = this.fb.group({
      date: ['', Validators.required],
      title: ['', [Validators.required, Validators.maxLength(200)]],
      description: ['', Validators.maxLength(1000)],
      activityType: [ItineraryActivityType.Sightseeing, Validators.required],
      location: ['', Validators.maxLength(200)],
      timeSlot: [ItineraryTimeSlot.Morning, Validators.required],
      notes: ['', Validators.maxLength(500)],
      isCompleted: [false]
    });
  }

  ngOnInit(): void {
    this.route.params.subscribe(params => {
      this.tripId = +params['tripId'];
      
      if (params['activityId'] && params['activityId'] !== 'new') {
        this.activityId = +params['activityId'];
        this.isEditMode = true;
        this.loadActivity();
      } else {
        // Check for date query parameter for pre-filling
        this.route.queryParams.subscribe(queryParams => {
          if (queryParams['date']) {
            this.activityForm.patchValue({ date: queryParams['date'] });
          }
          if (queryParams['timeSlot'] !== undefined) {
            this.activityForm.patchValue({ timeSlot: +queryParams['timeSlot'] });
          }
        });
      }
    });
  }

  loadActivity(): void {
    if (!this.activityId) return;

    this.isLoading = true;
    this.itineraryService.getItinerary(this.activityId).subscribe({
      next: (activity) => {
        console.log('Loaded activity:', activity);
        
        // Format date for HTML date input (YYYY-MM-DD)
        const formattedDate = this.formatDateForInput(activity.date);
        
        this.activityForm.patchValue({
          date: formattedDate,
          title: activity.title,
          description: activity.description,
          activityType: activity.activityType,
          location: activity.location,
          timeSlot: activity.timeSlot,
          notes: activity.notes,
          isCompleted: activity.isCompleted
        });
        this.isLoading = false;
      },
      error: (error) => {
        this.error = 'Errore nel caricamento dell\'attività';
        this.isLoading = false;
        console.error('Error loading activity:', error);
      }
    });
  }

  onSubmit(): void {
    if (this.activityForm.invalid) {
      this.activityForm.markAllAsTouched();
      return;
    }

    this.isSaving = true;
    this.error = null;

    const formValue = this.activityForm.value;

    if (this.isEditMode && this.activityId) {
      const updateDto: UpdateItineraryDto = {
        title: formValue.title,
        description: formValue.description || undefined,
        activityType: +formValue.activityType, // Convert to number
        location: formValue.location || undefined,
        timeSlot: +formValue.timeSlot, // Convert to number
        notes: formValue.notes || undefined,
        isCompleted: formValue.isCompleted
      };

      this.itineraryService.updateItinerary(this.activityId, updateDto).subscribe({
        next: () => {
          this.router.navigate(['/trips', this.tripId, 'itinerary']);
        },
        error: (error) => {
          this.error = 'Errore nell\'aggiornamento dell\'attività';
          this.isSaving = false;
          console.error('Error updating activity:', error);
        }
      });
    } else {
      const createDto: CreateItineraryDto = {
        tripId: this.tripId,
        date: formValue.date,
        title: formValue.title,
        description: formValue.description || undefined,
        activityType: +formValue.activityType, // Convert to number
        location: formValue.location || undefined,
        timeSlot: +formValue.timeSlot, // Convert to number
        notes: formValue.notes || undefined
      };

      this.itineraryService.createItinerary(createDto).subscribe({
        next: () => {
          this.router.navigate(['/trips', this.tripId, 'itinerary']);
        },
        error: (error) => {
          this.error = 'Errore nella creazione dell\'attività';
          this.isSaving = false;
          console.error('Error creating activity:', error);
        }
      });
    }
  }

  goBack(): void {
    this.router.navigate(['/trips', this.tripId, 'itinerary']);
  }

  getActivityTypeIcon(activityType: ItineraryActivityType): string {
    return this.itineraryService.getActivityTypeInfo(activityType).icon;
  }

  private formatDateForInput(date: string): string {
    // Handle different date formats and ensure YYYY-MM-DD format for HTML date input
    try {
      const dateObj = new Date(date);
      if (isNaN(dateObj.getTime())) {
        console.warn('Invalid date received:', date);
        return '';
      }
      
      // Format as YYYY-MM-DD
      const year = dateObj.getFullYear();
      const month = String(dateObj.getMonth() + 1).padStart(2, '0');
      const day = String(dateObj.getDate()).padStart(2, '0');
      
      return `${year}-${month}-${day}`;
    } catch (error) {
      console.error('Error formatting date:', error);
      return '';
    }
  }
}
