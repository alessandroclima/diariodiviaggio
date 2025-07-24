import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface TripItem {
  id: number;
  title: string;
  description?: string;
  type: string;
  location?: string;
  rating?: number;
  imageUrl?: string;
  createdAt: string;
  createdByUsername: string;
}

export interface CreateTripItemRequest {
  title: string;
  description?: string;
  type: string;
  location?: string;
  rating?: number;
  image?: File;
}

export interface UpdateTripItemRequest {
  title: string;
  description?: string;
  location?: string;
  rating?: number;
  image?: File;
  removeImage?: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class TripItemService {
  private apiUrl = `${environment.apiUrl}/api/tripitem`;

  constructor(private http: HttpClient) { }

  createTripItem(tripId: number, request: CreateTripItemRequest): Observable<TripItem> {
    const formData = new FormData();
    formData.append('title', request.title);
    if (request.description) {
      formData.append('description', request.description);
    }
    formData.append('type', request.type);
    if (request.location) {
      formData.append('location', request.location);
    }
    if (request.rating) {
      formData.append('rating', request.rating.toString());
    }
    if (request.image) {
      formData.append('image', request.image, request.image.name);
    }

    return this.http.post<TripItem>(`${this.apiUrl}/trip/${tripId}`, formData);
  }

  updateTripItem(id: number, request: UpdateTripItemRequest): Observable<TripItem> {
    const formData = new FormData();
    formData.append('title', request.title);
    if (request.description) {
      formData.append('description', request.description);
    }
    if (request.location) {
      formData.append('location', request.location);
    }
    if (request.rating) {
      formData.append('rating', request.rating.toString());
    }
    if (request.image) {
      formData.append('image', request.image, request.image.name);
    }
    if (request.removeImage) {
      formData.append('removeImage', 'true');
    }

    return this.http.put<TripItem>(`${this.apiUrl}/${id}`, formData);
  }

  getTripItem(id: number): Observable<TripItem> {
    return this.http.get<TripItem>(`${this.apiUrl}/${id}`);
  }

  getTripItems(tripId: number): Observable<TripItem[]> {
    return this.http.get<TripItem[]>(`${this.apiUrl}/trip/${tripId}`);
  }

  deleteTripItem(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }
}
