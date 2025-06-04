import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface Trip {
  id: number;
  title: string;
  description: string;
  startDate: string;
  endDate?: string;
  shareCode: string;
  ownerUsername: string;
  sharedWithUsernames: string[];
}

export interface CreateTripRequest {
  title: string;
  description?: string;
  startDate: string;
  endDate?: string;
}

export interface UpdateTripRequest {
  title: string;
  description?: string;
  startDate: string;
  endDate?: string;
}

@Injectable({
  providedIn: 'root'
})
export class TripService {
  private apiUrl = `${environment.apiUrl}/api/trip`;
  
  constructor(private http: HttpClient) { }

  createTrip(request: CreateTripRequest): Observable<Trip> {
    return this.http.post<Trip>(this.apiUrl, request);
  }

  updateTrip(id: number, request: UpdateTripRequest): Observable<Trip> {
    return this.http.put<Trip>(`${this.apiUrl}/${id}`, request);
  }

  getTrip(id: number): Observable<Trip> {
    return this.http.get<Trip>(`${this.apiUrl}/${id}`);
  }

  getUserTrips(): Observable<Trip[]> {
    return this.http.get<Trip[]>(this.apiUrl);
  }

  deleteTrip(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }

  shareTrip(id: number): Observable<Trip> {
    return this.http.post<Trip>(`${this.apiUrl}/${id}/share`, {});
  }

  joinTrip(shareCode: string): Observable<Trip> {
    return this.http.post<Trip>(`${this.apiUrl}/join/${shareCode}`, {});
  }
}
