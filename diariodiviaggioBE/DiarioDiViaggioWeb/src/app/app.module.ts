import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { HttpClientModule, HTTP_INTERCEPTORS, HttpClientXsrfModule } from '@angular/common/http';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { CommonModule, DatePipe } from '@angular/common';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { AuthInterceptor } from './interceptors/auth.interceptor';
import { SharedModule } from './components/shared/shared.module';

// ng-bootstrap import
import { NgbModule } from '@ng-bootstrap/ng-bootstrap';

// Components
import { LoginComponent } from './components/auth/login/login.component';
import { RegisterComponent } from './components/auth/register/register.component';
import { TripListComponent } from './components/trip/trip-list/trip-list.component';
import { TripDetailComponent } from './components/trip/trip-detail/trip-detail.component';
import { TripItemListComponent } from './components/trip-item/trip-item-list/trip-item-list.component';
import { TripItemFormComponent } from './components/trip-item/trip-item-form/trip-item-form.component';
import { LuggageListComponent } from './components/luggage/luggage-list/luggage-list.component';
import { LuggageDetailComponent } from './components/luggage/luggage-detail/luggage-detail.component';
import { HomeComponent } from './components/home/home.component';

// Pipes
import { FilterByPipe } from './pipes/filter-by.pipe';
import { RouterModule } from '@angular/router';
import { ProfileComponent } from './components/profile/profile.component';

@NgModule({
  declarations: [
    AppComponent,
    LoginComponent,
    RegisterComponent,
    TripListComponent,
    TripDetailComponent,
    TripItemListComponent,
    TripItemFormComponent,
    LuggageListComponent,
    LuggageDetailComponent,
    HomeComponent,
    FilterByPipe,
    ProfileComponent
  ],
  imports: [
    BrowserModule,
    BrowserAnimationsModule,
    HttpClientModule,
    HttpClientXsrfModule.withOptions({
      cookieName: 'XSRF-TOKEN',
      headerName: 'X-XSRF-TOKEN',
    }),
    FormsModule,
    ReactiveFormsModule,
    CommonModule,
    AppRoutingModule,
    SharedModule,
    NgbModule
  ],
  providers: [
    { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
    DatePipe
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
