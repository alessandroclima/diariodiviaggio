import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface LuggageItem {
  id: number;
  name: string;
  notes?: string;
  quantity: number;
  isPacked: boolean;
}

export interface Luggage {
  id: number;
  name: string;
  description?: string;
  items: LuggageItem[];
}

export interface CreateLuggageRequest {
  name: string;
  description?: string;
}

export interface UpdateLuggageRequest {
  name: string;
  description?: string;
}

export interface CreateLuggageItemRequest {
  name: string;
  notes?: string;
  quantity: number;
}

export interface UpdateLuggageItemRequest {
  name: string;
  notes?: string;
  quantity: number;
  isPacked: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class LuggageService {
  private apiUrl = `${environment.apiUrl}/api/luggage`;

  constructor(private http: HttpClient) { }

  createLuggage(tripId: number, request: CreateLuggageRequest): Observable<Luggage> {
    return this.http.post<Luggage>(`${this.apiUrl}/trip/${tripId}`, request);
  }

  updateLuggage(id: number, request: UpdateLuggageRequest): Observable<Luggage> {
    return this.http.put<Luggage>(`${this.apiUrl}/${id}`, request);
  }

  getLuggage(id: number): Observable<Luggage> {
    return this.http.get<Luggage>(`${this.apiUrl}/${id}`);
  }

  getTripLuggages(tripId: number): Observable<Luggage[]> {
    return this.http.get<Luggage[]>(`${this.apiUrl}/trip/${tripId}`);
  }

  deleteLuggage(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }

  // Luggage Item operations
  addLuggageItem(luggageId: number, request: CreateLuggageItemRequest): Observable<LuggageItem> {
    return this.http.post<LuggageItem>(`${this.apiUrl}/${luggageId}/items`, request);
  }

  updateLuggageItem(itemId: number, request: UpdateLuggageItemRequest): Observable<LuggageItem> {
    return this.http.put<LuggageItem>(`${this.apiUrl}/items/${itemId}`, request);
  }

  getLuggageItem(itemId: number): Observable<LuggageItem> {
    return this.http.get<LuggageItem>(`${this.apiUrl}/items/${itemId}`);
  }

  deleteLuggageItem(itemId: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/items/${itemId}`);
  }
}
