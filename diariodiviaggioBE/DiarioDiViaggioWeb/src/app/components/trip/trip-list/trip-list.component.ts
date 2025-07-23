import { Component, OnInit } from '@angular/core';
import { TripService, Trip } from '../../../services/trip.service';
import { NotificationService } from '../../../services/notification.service';

@Component({
  selector: 'app-trip-list',
  templateUrl: './trip-list.component.html',
  styleUrls: ['./trip-list.component.scss']
})
export class TripListComponent implements OnInit {
  trips: Trip[] = [];
  isLoading = false;
  shareCode = '';

  constructor(
    private tripService: TripService,
    private notificationService: NotificationService
  ) { }

  ngOnInit(): void {
    this.loadTrips();
  }

  loadTrips(): void {
    this.isLoading = true;
    this.tripService.getUserTrips()
      .subscribe({
        next: (trips) => {
          this.trips = trips;
          this.isLoading = false;
        },
        error: (error) => {
          this.notificationService.showError(error.error?.message || 'Errore nel caricamento dei viaggi');
          this.isLoading = false;
        }
      });
  }

  joinTrip(): void {
    if (!this.shareCode) return;

    this.isLoading = true;
    this.tripService.joinTrip(this.shareCode)
      .subscribe({
        next: (trip) => {
          this.notificationService.showSuccess(`Ti sei unito al viaggio ${trip.title} con successo!`);
          this.loadTrips();
          this.shareCode = '';
          this.isLoading = false;
        },
        error: (error) => {
          this.notificationService.showError(error.error?.message || 'Codice di condivisione non valido');
          this.isLoading = false;
        }
      });
  }
}
