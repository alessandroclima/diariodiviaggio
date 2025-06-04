import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { LoginComponent } from './components/auth/login/login.component';
import { RegisterComponent } from './components/auth/register/register.component';
import { HomeComponent } from './components/home/home.component';
import { TripListComponent } from './components/trip/trip-list/trip-list.component';
import { TripDetailComponent } from './components/trip/trip-detail/trip-detail.component';
import { TripItemListComponent } from './components/trip-item/trip-item-list/trip-item-list.component';
import { TripItemFormComponent } from './components/trip-item/trip-item-form/trip-item-form.component';
import { LuggageListComponent } from './components/luggage/luggage-list/luggage-list.component';

import { AuthGuard } from './guards/auth.guard';

const routes: Routes = [
  { path: '', component: HomeComponent },
  { path: 'login', component: LoginComponent },
  { path: 'register', component: RegisterComponent },
  { path: 'trips', component: TripListComponent, canActivate: [AuthGuard] },
  { path: 'trips/new', component: TripDetailComponent, canActivate: [AuthGuard] },
  { path: 'trips/:id', component: TripDetailComponent, canActivate: [AuthGuard] },
  { path: 'trips/:id/items', component: TripItemListComponent, canActivate: [AuthGuard] },
  { path: 'trips/:id/items/new', component: TripItemFormComponent, canActivate: [AuthGuard] },
  { path: 'trips/:tripId/items/:id', component: TripItemFormComponent, canActivate: [AuthGuard] },
  { path: 'trips/:id/luggage', component: LuggageListComponent, canActivate: [AuthGuard] },
  { path: '**', redirectTo: '' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
