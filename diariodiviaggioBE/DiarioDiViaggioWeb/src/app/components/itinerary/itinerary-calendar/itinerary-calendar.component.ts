import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { ItineraryService, TripItineraryCalendarDto, ItineraryDto, ItineraryActivityType, ItineraryTimeSlot } from '../../../services/itinerary.service';

interface WeekDay {
  date: string;
  dayNumber: number;
  dayName: string;
  isTripDay: boolean;
  isToday: boolean;
  activities: ItineraryDto[];
}

@Component({
  selector: 'app-itinerary-calendar',
  templateUrl: './itinerary-calendar.component.html',
  styleUrls: ['./itinerary-calendar.component.scss']
})
export class ItineraryCalendarComponent implements OnInit {
  tripId!: number;
  calendar: TripItineraryCalendarDto | null = null;
  isLoading = true;
  error: string | null = null;
  selectedDate: string | null = null;
  
  currentWeekStart = new Date();
  weekDays: WeekDay[] = [];
  currentWeekRange = '';

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private itineraryService: ItineraryService
  ) { }

  ngOnInit(): void {
    this.route.params.subscribe(params => {
      this.tripId = +params['id'];
      this.loadItineraryCalendar();
    });
  }

  loadItineraryCalendar(): void {
    this.isLoading = true;
    this.error = null;

    this.itineraryService.getTripItineraryCalendar(this.tripId).subscribe({
      next: (calendar) => {
        this.calendar = calendar;
        this.initializeWeekFromTrip();
        this.generateWeekGrid();
        this.isLoading = false;
      },
      error: (error) => {
        this.error = 'Errore nel caricamento dell\'itinerario';
        this.isLoading = false;
        console.error('Error loading itinerary calendar:', error);
      }
    });
  }

  initializeWeekFromTrip(): void {
    if (!this.calendar) return;
    
    // Parse the trip start date as string to avoid timezone issues
    const tripStartDateStr = this.calendar.startDate.split('T')[0]; // Get just YYYY-MM-DD
    const [year, month, day] = tripStartDateStr.split('-').map(Number);
    
    // Create date using local timezone (month is 0-based)
    const tripStartDate = new Date(year, month - 1, day);
    this.currentWeekStart = this.getWeekStart(tripStartDate);
  }

  getWeekStart(date: Date): Date {
    const weekStart = new Date(date);
    const day = weekStart.getDay();
    const diff = weekStart.getDate() - day + (day === 0 ? -6 : 1); // Monday as first day
    weekStart.setDate(diff);
    weekStart.setHours(0, 0, 0, 0);
    return weekStart;
  }

  onDateSelected(date: string): void {
    this.selectedDate = this.selectedDate === date ? null : date;
  }

  editActivity(activityId: number): void {
    this.router.navigate(['/trips', this.tripId, 'itinerary', activityId, 'edit']);
  }

  toggleActivityCompletion(activity: ItineraryDto): void {
    const updateDto = {
      title: activity.title,
      description: activity.description,
      activityType: activity.activityType,
      location: activity.location,
      timeSlot: activity.timeSlot,
      notes: activity.notes,
      isCompleted: !activity.isCompleted
    };

    this.itineraryService.updateItinerary(activity.id, updateDto).subscribe({
      next: () => {
        activity.isCompleted = !activity.isCompleted;
      },
      error: (error) => {
        console.error('Error updating activity:', error);
      }
    });
  }

  deleteActivity(activityId: number): void {
    if (confirm('Sei sicuro di voler eliminare questa attività?')) {
      this.itineraryService.deleteItinerary(activityId).subscribe({
        next: () => {
          this.loadItineraryCalendar();
        },
        error: (error) => {
          console.error('Error deleting activity:', error);
        }
      });
    }
  }

  getActivityIcon(activityType: ItineraryActivityType): string {
    return this.itineraryService.getActivityTypeInfo(activityType).icon;
  }

  getActivityTypeName(activityType: ItineraryActivityType): string {
    return this.itineraryService.getActivityTypeInfo(activityType).label;
  }

  getTimeSlotIcon(timeSlot: ItineraryTimeSlot): string {
    return this.itineraryService.getTimeSlotInfo(timeSlot).icon;
  }

  getTimeSlotLabel(timeSlot: ItineraryTimeSlot): string {
    return this.itineraryService.getTimeSlotInfo(timeSlot).label;
  }

  formatDate(dateStr: string): string {
    const date = new Date(dateStr);
    return date.toLocaleDateString('it-IT', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    });
  }

  generateWeekGrid(): void {
    if (!this.calendar) return;

    // Generate week range display
    const weekEnd = new Date(this.currentWeekStart);
    weekEnd.setDate(weekEnd.getDate() + 6);
    
    this.currentWeekRange = `${this.currentWeekStart.toLocaleDateString('it-IT', { 
      day: '2-digit', 
      month: 'short' 
    })} - ${weekEnd.toLocaleDateString('it-IT', { 
      day: '2-digit', 
      month: 'short', 
      year: 'numeric' 
    })}`;

    // Generate 7 days for the week
    this.weekDays = [];
    const today = new Date().toISOString().split('T')[0];
   
    // Use date strings instead of timestamps to avoid timezone issues
    const tripStartDate = this.calendar.startDate.split('T')[0]; // Get just YYYY-MM-DD
    const tripEndDate = this.calendar.endDate ? this.calendar.endDate.split('T')[0] : tripStartDate;

    const dayNames = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

    for (let i = 0; i < 7; i++) {
      // Create date using local time zone to avoid timezone shifts
      const currentDay = new Date(this.currentWeekStart.getFullYear(), this.currentWeekStart.getMonth(), this.currentWeekStart.getDate() + i);
      
      const year = currentDay.getFullYear();
      const month = String(currentDay.getMonth() + 1).padStart(2, '0');
      const day = String(currentDay.getDate()).padStart(2, '0');
      const dateString = `${year}-${month}-${day}`;
      
      // Get activities for this day
      const dayActivities = this.calendar.calendar.find(d => 
        d.date.split('T')[0] === dateString
      )?.activities || [];

      // Compare date strings instead of timestamps
      const isTripDay = dateString >= tripStartDate && dateString <= tripEndDate;

      this.weekDays.push({
        date: dateString,
        dayNumber: currentDay.getDate(),
        dayName: dayNames[i],
        isTripDay: isTripDay,
        isToday: dateString === today,
        activities: dayActivities
      });
    }
  }

  previousWeek(): void {
    this.currentWeekStart.setDate(this.currentWeekStart.getDate() - 7);
    this.generateWeekGrid();
  }

  nextWeek(): void {
    this.currentWeekStart.setDate(this.currentWeekStart.getDate() + 7);
    this.generateWeekGrid();
  }

  getMorningActivities(date: string): ItineraryDto[] {
    const day = this.weekDays.find(d => d.date === date);
    return day?.activities.filter((a: ItineraryDto) => a.timeSlot === ItineraryTimeSlot.Morning) || [];
  }

  getAfternoonActivities(date: string): ItineraryDto[] {
    const day = this.weekDays.find(d => d.date === date);
    return day?.activities.filter((a: ItineraryDto) => a.timeSlot === ItineraryTimeSlot.Afternoon) || [];
  }

  addActivity(date: string, timeSlot?: ItineraryTimeSlot): void {
    const queryParams: any = { date };
    if (timeSlot !== undefined) {
      queryParams.timeSlot = timeSlot;
    }
    this.router.navigate(['/trips', this.tripId, 'itinerary', 'new'], { queryParams });
  }

  goBack(): void {
    this.router.navigate(['/trips', this.tripId]);
  }
}
