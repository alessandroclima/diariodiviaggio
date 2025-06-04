import { Component, OnInit } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { TripService, Trip } from '../../../services/trip.service';

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
    private snackBar: MatSnackBar
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
          this.snackBar.open(error.error?.message || 'Errore nel caricamento dei viaggi', 'Chiudi', {
            duration: 5000,
          });
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
          this.snackBar.open(`Ti sei unito al viaggio ${trip.title} con successo!`, 'Chiudi', {
            duration: 5000,
          });
          this.loadTrips();
          this.shareCode = '';
          this.isLoading = false;
        },
        error: (error) => {
          this.snackBar.open(error.error?.message || 'Codice di condivisione non valido', 'Chiudi', {
            duration: 5000,
          });
          this.isLoading = false;
        }
      });
  }
}
