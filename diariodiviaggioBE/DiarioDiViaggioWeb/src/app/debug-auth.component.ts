import { Component } from '@angular/core';
import { AuthService } from './services/auth.service';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-debug-auth',
  template: `
    <div style="padding: 20px; border: 2px solid #ccc; margin: 20px;">
      <h3>Authentication Debug Panel</h3>
      
      <div style="margin: 10px 0;">
        <button (click)="checkAuthState()" style="margin-right: 10px;">Check Auth State</button>
        <button (click)="testRefresh()" style="margin-right: 10px;">Test Refresh</button>
        <button (click)="checkCookies()" style="margin-right: 10px;">Check Cookies</button>
        <button (click)="clearAll()">Clear All</button>
      </div>
      
      <div style="background: #f5f5f5; padding: 10px; margin-top: 10px;">
        <pre>{{ debugInfo }}</pre>
      </div>
    </div>
  `
})
export class DebugAuthComponent {
  debugInfo = 'Click buttons to debug authentication...';

  constructor(
    private authService: AuthService,
    private http: HttpClient
  ) {}

  checkAuthState() {
    const info = {
      isLoggedIn: this.authService.isLoggedIn(),
      hasToken: !!this.authService.getToken(),
      token: this.authService.getToken()?.substring(0, 20) + '...',
      currentUser: null as any,
      localStorage: localStorage.getItem('auth_token')?.substring(0, 20) + '...',
      documentCookies: document.cookie,
      currentUrl: window.location.href,
      origin: window.location.origin
    };

    this.authService.currentUser$.subscribe(user => {
      info.currentUser = user;
      this.debugInfo = JSON.stringify(info, null, 2);
    });
  }

  testRefresh() {
    console.log('=== Testing Refresh Token ===');
    this.authService.refreshToken().subscribe({
      next: (response) => {
        this.debugInfo = `Refresh SUCCESS:\n${JSON.stringify(response, null, 2)}`;
        console.log('Refresh successful:', response);
      },
      error: (error) => {
        this.debugInfo = `Refresh ERROR:\n${JSON.stringify(error, null, 2)}`;
        console.error('Refresh failed:', error);
      }
    });
  }

  checkCookies() {
    const info = {
      allCookies: document.cookie,
      cookieCount: document.cookie.split(';').length,
      domain: document.domain,
      secure: window.location.protocol === 'https:',
      sameSite: 'Check browser dev tools for SameSite',
      httpOnly: 'HttpOnly cookies not visible in JavaScript (this is correct)'
    };
    this.debugInfo = JSON.stringify(info, null, 2);
  }

  clearAll() {
    localStorage.clear();
    document.cookie.split(";").forEach(c => {
      const eqPos = c.indexOf("=");
      const name = eqPos > -1 ? c.substr(0, eqPos) : c;
      document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/";
    });
    this.debugInfo = 'All local storage and visible cookies cleared.';
  }
}
