import { Component, Input, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import {
  Luggage,
  LuggageService,
  CreateLuggageRequest,
} from '../../../services/luggage.service';
import { ConfirmDialogComponent } from '../../shared/confirm-dialog/confirm-dialog.component';
import { NotificationService } from '../../../services/notification.service';
import { Trip, TripService } from '../../../services/trip.service';

@Component({
  selector: 'app-luggage-list',
  templateUrl: './luggage-list.component.html',
  styleUrls: ['./luggage-list.component.scss'],
})
export class LuggageListComponent implements OnInit {
  @Input() tripId!: number;

  luggages: Luggage[] = [];
  availableTrips: Trip[] = [];
  selectedExportTripIds: Record<number, number> = {};
  exportingLuggageId: number | null = null;
  loading = true;
  error = false;
  showAddForm = false;

  newLuggage: CreateLuggageRequest = {
    name: '',
    description: '',
  };

  constructor(
    private router: Router,
    private luggageService: LuggageService,
    private tripService: TripService,
    private modal: NgbModal,
    private notificationService: NotificationService,
  ) {}

  ngOnInit(): void {
    this.loadTrips();
    this.loadLuggages();
  }

  loadTrips(): void {
    this.tripService.getUserTrips().subscribe({
      next: (trips) => {
        this.availableTrips = trips.filter((t) => t.id !== this.tripId);
        this.syncSelectedExportTargets();
      },
      error: () => {
        this.availableTrips = [];
        this.selectedExportTripIds = {};
      },
    });
  }

  loadLuggages(): void {
    this.loading = true;
    this.error = false;

    this.luggageService.getTripLuggages(this.tripId).subscribe({
      next: (luggages) => {
        this.luggages = luggages;
        this.syncSelectedExportTargets();
        this.loading = false;
      },
      error: (err) => {
        console.error('Error loading luggages:', err);
        this.loading = false;
        this.error = true;
        this.notificationService.showError('Failed to load luggage lists');
      },
    });
  }

  private syncSelectedExportTargets(): void {
    if (this.availableTrips.length === 0) {
      this.selectedExportTripIds = {};
      return;
    }

    const defaultTripId = this.availableTrips[0].id;
    const nextSelections: Record<number, number> = {};

    for (const luggage of this.luggages) {
      const selected = this.selectedExportTripIds[luggage.id];
      const existsInOptions = this.availableTrips.some(
        (t) => t.id === selected,
      );
      nextSelections[luggage.id] = existsInOptions ? selected : defaultTripId;
    }

    this.selectedExportTripIds = nextSelections;
  }

  exportLuggage(luggage: Luggage): void {
    const targetTripId = this.selectedExportTripIds[luggage.id];
    if (!targetTripId) {
      this.notificationService.showError(
        'Select a destination trip before exporting',
      );
      return;
    }

    this.exportingLuggageId = luggage.id;
    this.luggageService.exportLuggage(luggage.id, { targetTripId }).subscribe({
      next: () => {
        this.notificationService.showSuccess('Luggage exported successfully');
        this.exportingLuggageId = null;
      },
      error: (err) => {
        this.notificationService.showError(
          err.error?.message || 'Failed to export luggage',
        );
        this.exportingLuggageId = null;
      },
    });
  }

  toggleAddForm(): void {
    this.showAddForm = !this.showAddForm;
    if (this.showAddForm) {
      // Reset form
      this.newLuggage = {
        name: '',
        description: '',
      };
    }
  }

  createLuggage(): void {
    if (!this.newLuggage.name.trim()) {
      this.notificationService.showError(
        'Please provide a name for the luggage list',
      );
      return;
    }

    this.luggageService.createLuggage(this.tripId, this.newLuggage).subscribe({
      next: (luggage) => {
        this.luggages.push(luggage);
        this.showAddForm = false;
        this.notificationService.showSuccess(
          'Luggage list created successfully',
        );
      },
      error: (err) => {
        console.error('Error creating luggage:', err);
        this.notificationService.showError('Failed to create luggage list');
      },
    });
  }

  deleteLuggage(luggage: Luggage): void {
    const modalRef = this.modal.open(ConfirmDialogComponent);
    modalRef.componentInstance.title = 'Delete Luggage';
    modalRef.componentInstance.message = `Are you sure you want to delete "${luggage.name}"?`;
    modalRef.componentInstance.confirmButtonText = 'Delete';

    modalRef.result
      .then((result: boolean) => {
        if (result) {
          this.luggageService.deleteLuggage(luggage.id).subscribe({
            next: () => {
              this.luggages = this.luggages.filter((l) => l.id !== luggage.id);
              this.notificationService.showSuccess(
                'Luggage list deleted successfully',
              );
            },
            error: (err) => {
              console.error('Error deleting luggage:', err);
              this.notificationService.showError(
                'Failed to delete luggage list',
              );
            },
          });
        }
      })
      .catch(() => {
        // Modal dismissed
      });
  }

  getPackedItemsCount(items: any[]): number {
    return items.filter((item) => item.isPacked).length;
  }

  getPackingProgress(items: any[]): number {
    if (!items || items.length === 0) return 0;
    return (this.getPackedItemsCount(items) / items.length) * 100;
  }

  navigateToLuggageDetail(luggage: Luggage): void {
    this.router.navigate(['/trips', this.tripId, 'luggage', luggage.id]);
  }
}
