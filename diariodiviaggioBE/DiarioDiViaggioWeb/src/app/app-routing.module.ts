import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { LoginComponent } from './components/auth/login/login.component';
import { RegisterComponent } from './components/auth/register/register.component';
import { ForgotPasswordComponent } from './components/forgot-password/forgot-password.component';
import { ResetPasswordComponent } from './components/reset-password/reset-password.component';
import { HomeComponent } from './components/home/home.component';
import { TripListComponent } from './components/trip/trip-list/trip-list.component';
import { TripDetailComponent } from './components/trip/trip-detail/trip-detail.component';
import { TripItemListComponent } from './components/trip-item/trip-item-list/trip-item-list.component';
import { TripItemFormComponent } from './components/trip-item/trip-item-form/trip-item-form.component';
import { LuggageListComponent } from './components/luggage/luggage-list/luggage-list.component';
import { LuggageDetailComponent } from './components/luggage/luggage-detail/luggage-detail.component';
import { ItineraryCalendarComponent } from './components/itinerary/itinerary-calendar/itinerary-calendar.component';
import { ItineraryFormComponent } from './components/itinerary/itinerary-form/itinerary-form.component';
import { ProfileComponent } from './components/profile/profile.component';

import { AuthGuard } from './guards/auth.guard';


const routes: Routes = [
  { path: '', component: HomeComponent },
  { path: 'login', component: LoginComponent },
  { path: 'register', component: RegisterComponent },
  { path: 'forgot-password', component: ForgotPasswordComponent },
  { path: 'reset-password', component: ResetPasswordComponent },
  { path: 'profile', component: ProfileComponent, canActivate: [AuthGuard] },
  { path: 'trips', component: TripListComponent, canActivate: [AuthGuard] },
  { path: 'trips/new', component: TripDetailComponent, canActivate: [AuthGuard] },
  { path: 'trips/:id', component: TripDetailComponent, canActivate: [AuthGuard] },
  { path: 'trips/:id/itinerary', component: ItineraryCalendarComponent, canActivate: [AuthGuard] },
  { path: 'trips/:tripId/itinerary/new', component: ItineraryFormComponent, canActivate: [AuthGuard] },
  { path: 'trips/:tripId/itinerary/:activityId/edit', component: ItineraryFormComponent, canActivate: [AuthGuard] },
  { path: 'trips/:tripId/items', component: TripItemListComponent, canActivate: [AuthGuard] },
  { path: 'trips/:tripId/items/new', component: TripItemFormComponent, canActivate: [AuthGuard] },
  { path: 'trips/:tripId/items/:id', component: TripItemFormComponent, canActivate: [AuthGuard] },
  { path: 'trips/:tripId/luggage', component: LuggageListComponent, canActivate: [AuthGuard] },
  { path: 'trips/:tripId/luggage/:luggageId', component: LuggageDetailComponent, canActivate: [AuthGuard] },
  { path: '**', redirectTo: '' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes,{bindToComponentInputs: true})],
  exports: [RouterModule]
})
export class AppRoutingModule { }
