import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface CreateItineraryDto {
  tripId: number;
  date: string;
  title: string;
  description?: string;
  activityType: ItineraryActivityType;
  location?: string;
  timeSlot: ItineraryTimeSlot;
  notes?: string;
}

export interface UpdateItineraryDto {
  title: string;
  description?: string;
  activityType: ItineraryActivityType;
  location?: string;
  timeSlot: ItineraryTimeSlot;
  notes?: string;
  isCompleted: boolean;
}

export interface ItineraryDto {
  id: number;
  tripId: number;
  date: string;
  title: string;
  description?: string;
  activityType: ItineraryActivityType;
  activityTypeName: string;
  location?: string;
  timeSlot: ItineraryTimeSlot;
  timeSlotName: string;
  notes?: string;
  isCompleted: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ItineraryCalendarDto {
  date: string;
  activities: ItineraryDto[];
  hasActivities: boolean;
}

export interface TripItineraryCalendarDto {
  tripId: number;
  tripTitle: string;
  startDate: string;
  endDate?: string;
  calendar: ItineraryCalendarDto[];
}

export enum ItineraryTimeSlot {
  Morning = 0,
  Afternoon = 1
}

export enum ItineraryActivityType {
  Sightseeing = 0,
  Restaurant = 1,
  Transportation = 2,
  Accommodation = 3,
  Shopping = 4,
  Entertainment = 5,
  Outdoor = 6,
  Cultural = 7,
  Relaxation = 8,
  Business = 9,
  Other = 10
}

@Injectable({
  providedIn: 'root'
})
export class ItineraryService {
  private apiUrl = `${environment.apiUrl}/api/itinerary`;

  constructor(private http: HttpClient) { }

  createItinerary(itinerary: CreateItineraryDto): Observable<ItineraryDto> {
    return this.http.post<ItineraryDto>(this.apiUrl, itinerary);
  }

  getItinerary(id: number): Observable<ItineraryDto> {
    return this.http.get<ItineraryDto>(`${this.apiUrl}/${id}`);
  }

  getItinerariesByTrip(tripId: number): Observable<ItineraryDto[]> {
    return this.http.get<ItineraryDto[]>(`${this.apiUrl}/trip/${tripId}`);
  }

  getTripItineraryCalendar(tripId: number): Observable<TripItineraryCalendarDto> {
    return this.http.get<TripItineraryCalendarDto>(`${this.apiUrl}/trip/${tripId}/calendar`);
  }

  getItinerariesByDate(tripId: number, date: string): Observable<ItineraryDto[]> {
    return this.http.get<ItineraryDto[]>(`${this.apiUrl}/trip/${tripId}/date/${date}`);
  }

  updateItinerary(id: number, itinerary: UpdateItineraryDto): Observable<ItineraryDto> {
    return this.http.put<ItineraryDto>(`${this.apiUrl}/${id}`, itinerary);
  }

  deleteItinerary(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }

  getActivityTypeOptions(): Array<{value: ItineraryActivityType, label: string, icon: string}> {
    return [
      { value: ItineraryActivityType.Sightseeing, label: 'Turismo', icon: 'bi-camera' },
      { value: ItineraryActivityType.Restaurant, label: 'Ristorante', icon: 'bi-cup-hot' },
      { value: ItineraryActivityType.Transportation, label: 'Trasporto', icon: 'bi-bus-front' },
      { value: ItineraryActivityType.Accommodation, label: 'Alloggio', icon: 'bi-house' },
      { value: ItineraryActivityType.Shopping, label: 'Shopping', icon: 'bi-bag' },
      { value: ItineraryActivityType.Entertainment, label: 'Intrattenimento', icon: 'bi-ticket-perforated' },
      { value: ItineraryActivityType.Outdoor, label: 'Attività all\'aperto', icon: 'bi-tree' },
      { value: ItineraryActivityType.Cultural, label: 'Cultura', icon: 'bi-building' },
      { value: ItineraryActivityType.Relaxation, label: 'Relax', icon: 'bi-heart' },
      { value: ItineraryActivityType.Business, label: 'Business', icon: 'bi-briefcase' },
      { value: ItineraryActivityType.Other, label: 'Altro', icon: 'bi-three-dots' }
    ];
  }

  getActivityTypeInfo(type: ItineraryActivityType): {label: string, icon: string} {
    const options = this.getActivityTypeOptions();
    const option = options.find(o => o.value === type);
    return option ? { label: option.label, icon: option.icon } : { label: 'Altro', icon: 'bi-three-dots' };
  }

  getTimeSlotOptions(): Array<{value: ItineraryTimeSlot, label: string, icon: string}> {
    return [
      { value: ItineraryTimeSlot.Morning, label: 'Mattina', icon: 'bi-sunrise' },
      { value: ItineraryTimeSlot.Afternoon, label: 'Pomeriggio', icon: 'bi-sunset' }
    ];
  }

  getTimeSlotInfo(timeSlot: ItineraryTimeSlot): {label: string, icon: string} {
    const options = this.getTimeSlotOptions();
    const option = options.find(o => o.value === timeSlot);
    return option ? { label: option.label, icon: option.icon } : { label: 'Mattina', icon: 'bi-sunrise' };
  }
}
