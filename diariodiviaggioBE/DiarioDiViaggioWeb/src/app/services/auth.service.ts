import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, tap, of, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface RegisterRequest {
  username: string;
  email: string;
  password: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthResponse {
  token: string;
  username: string;
  email: string;
  profileImageBase64?: string;
}

export interface User {
  username: string;
  email: string;
  profileImageBase64?: string;
}

export interface PasswordResetRequest {
  email: string;
}

export interface PasswordReset {
  token: string;
  newPassword: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = `${environment.apiUrl}/api/auth`;
  private tokenKey = 'auth_token';
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();
  private isLoggingOut = false; // Prevent multiple logout calls
  
  constructor(private http: HttpClient) {
    this.loadUserFromStorage();
  }

  register(request: RegisterRequest): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/register`, request, { withCredentials: true })
      .pipe(
        tap(response => this.handleAuthentication(response))
      );
  }

  login(request: LoginRequest): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/login`, request, { withCredentials: true })
      .pipe(
        tap(response => this.handleAuthentication(response))
      );
  }

  logout(): void {
    // Prevent multiple logout calls
    if (this.isLoggingOut) {
      console.log('Logout already in progress');
      return;
    }
    
    this.isLoggingOut = true;
    console.log('Starting logout process');
    
    // Always clear local storage immediately to prevent UI issues
    this.clearLocalStorage();
    this.currentUserSubject.next(null);
    
    // Try to revoke the refresh token on the server (best effort)
    this.revokeRefreshToken().subscribe({
      next: () => {
        console.log('Refresh token revoked successfully on server');
      },
      error: (error) => {
        console.error('Failed to revoke refresh token on server:', error);
        // Don't fail the logout process even if server revocation fails
      },
      complete: () => {
        this.isLoggingOut = false;
        console.log('Logout process completed');
      }
    });
  }

  private clearLocalStorage(): void {
    console.log('Clearing localStorage...');
    console.log('Before clear - token exists:', !!localStorage.getItem(this.tokenKey));
    
    localStorage.removeItem(this.tokenKey);
    
    console.log('After clear - token exists:', !!localStorage.getItem(this.tokenKey));
  }

  isLoggedIn(): boolean {
    return !!this.getToken();
  }

  getToken(): string | null {
    return localStorage.getItem(this.tokenKey);
  }

  refreshToken(): Observable<{token: string}> {
    // HttpOnly cookie will be sent automatically with the request
    return this.http.post<{token: string}>(`${this.apiUrl}/refresh`, {}, { withCredentials: true }).pipe(
      tap(response => {
        // Only store the new JWT token, refresh token is handled by HttpOnly cookie
        localStorage.setItem(this.tokenKey, response.token);
        console.log('Token refreshed successfully');
      })
    );
  }

  private revokeRefreshToken(): Observable<any> {
    console.log('Attempting to revoke refresh token via HttpOnly cookie');
    
    // HttpOnly cookie will be sent automatically with the request
    console.log('Sending revoke request to:', `${this.apiUrl}/revoke`);
    return this.http.post(`${this.apiUrl}/revoke`, {}, { withCredentials: true }).pipe(
      tap(response => {
        console.log('Revoke response:', response);
      }),
      catchError((error) => {
        console.error('Revoke error:', error);
        return of(null); // Don't fail logout if revoke fails
      })
    );
  }

  private handleAuthentication(response: AuthResponse): void {
    // Only store JWT token, refresh token is handled by HttpOnly cookie
    localStorage.setItem(this.tokenKey, response.token);
    const user: User = {
      username: response.username,
      email: response.email,
      profileImageBase64: response.profileImageBase64
    };
    this.currentUserSubject.next(user);
  }

  private loadUserFromStorage(): void {
    const token = this.getToken();
    if (token) {
      const payload = JSON.parse(atob(token.split('.')[1]));
      const user: User = {
        username: payload.unique_name,
        email: payload.email,
        profileImageBase64: undefined // Will be loaded separately if needed
      };
      this.currentUserSubject.next(user);
    }
  }

  updateCurrentUser(user: User): void {
    this.currentUserSubject.next(user);
  }

  requestPasswordReset(request: PasswordResetRequest): Observable<{message: string}> {
    return this.http.post<{message: string}>(`${this.apiUrl}/forgot-password`, request, { withCredentials: true });
  }

  resetPassword(resetData: PasswordReset): Observable<{message: string}> {
    return this.http.post<{message: string}>(`${this.apiUrl}/reset-password`, resetData, { withCredentials: true });
  }
}
