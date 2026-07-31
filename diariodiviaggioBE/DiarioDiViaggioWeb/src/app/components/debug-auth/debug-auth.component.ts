import { Component } from '@angular/core';
import { AuthService } from '../../services/auth.service';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-debug-auth',
  template: `
    <div class="container mt-4">
      <div class="card">
        <div class="card-header">
          <h3>🔧 Authentication Debug Panel</h3>
        </div>
        <div class="card-body">
          <!-- Current State -->
          <div class="row mb-4">
            <div class="col-md-6">
              <h5>Current Authentication State</h5>
              <div
                class="alert"
                [class]="isLoggedIn ? 'alert-success' : 'alert-warning'"
              >
                <strong>Status:</strong>
                {{ isLoggedIn ? 'Logged In' : 'Not Logged In' }}<br />
                <strong>Token Present:</strong> {{ hasToken ? 'Yes' : 'No'
                }}<br />
                <strong>Token Preview:</strong> {{ tokenPreview || 'None' }}
              </div>
            </div>
            <div class="col-md-6">
              <h5>Browser Cookie Info</h5>
              <div class="alert alert-info">
                <strong>All Cookies:</strong><br />
                <code
                  >{{ allCookies || 'No cookies visible (HttpOnly cookies won't show here)' }}</code
                >
              </div>
            </div>
          </div>

          <!-- Action Buttons -->
          <div class="row mb-4">
            <div class="col-12">
              <h5>Debug Actions</h5>
              <button
                class="btn btn-primary me-2 mb-2"
                (click)="checkAuthState()"
              >
                🔍 Check Auth State
              </button>
              <button
                class="btn btn-secondary me-2 mb-2"
                (click)="testRefresh()"
              >
                🔄 Test Refresh Token
              </button>
              <button class="btn btn-info me-2 mb-2" (click)="checkCookies()">
                🍪 Check Cookie Status
              </button>
              <button
                class="btn btn-success me-2 mb-2"
                (click)="testCookieEndpoint()"
              >
                🧪 Test Cookie Endpoint
              </button>
              <button class="btn btn-warning me-2 mb-2" (click)="clearAll()">
                🗑️ Clear All Auth Data
              </button>
            </div>
          </div>

          <!-- Debug Output -->
          <div class="row" *ngIf="debugOutput.length > 0">
            <div class="col-12">
              <h5>Debug Output</h5>
              <div
                class="alert alert-light"
                style="max-height: 400px; overflow-y: auto;"
              >
                <div
                  *ngFor="let output of debugOutput; let i = index"
                  [class]="
                    'mb-1 p-2 border-start border-3 ' +
                    (output.type === 'error'
                      ? 'border-danger bg-light-danger'
                      : output.type === 'success'
                        ? 'border-success bg-light-success'
                        : 'border-info bg-light-info')
                  "
                >
                  <small class="text-muted">{{ output.timestamp }}</small
                  ><br />
                  <strong>{{ output.title }}</strong
                  ><br />
                  <span>{{ output.message }}</span>
                  <pre
                    *ngIf="output.data"
                    class="mt-1 mb-0"
                  ><code>{{ formatData(output.data) }}</code></pre>
                </div>
              </div>
              <button
                class="btn btn-sm btn-outline-secondary mt-2"
                (click)="clearDebugOutput()"
              >
                Clear Output
              </button>
            </div>
          </div>

          <!-- Instructions -->
          <div class="row mt-4">
            <div class="col-12">
              <div class="alert alert-light">
                <h6>💡 How to Use This Debug Panel:</h6>
                <ol class="mb-0">
                  <li>
                    <strong>Login first</strong> using the normal login form
                  </li>
                  <li>
                    <strong>Click "Check Auth State"</strong> to see current
                    status
                  </li>
                  <li>
                    <strong>Click "Check Cookie Status"</strong> to see what
                    cookies are available
                  </li>
                  <li>
                    <strong>Click "Test Cookie Endpoint"</strong> to verify
                    backend receives cookies
                  </li>
                  <li>
                    <strong>Click "Test Refresh Token"</strong> to manually
                    trigger token refresh
                  </li>
                  <li>
                    <strong>Watch the browser's Network tab</strong> to see HTTP
                    requests and cookie headers
                  </li>
                  <li>
                    <strong>Check browser console</strong> for additional debug
                    messages
                  </li>
                </ol>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [
    `
      .bg-light-success {
        background-color: #f8f9fa !important;
      }
      .bg-light-danger {
        background-color: #f8f9fa !important;
      }
      .bg-light-info {
        background-color: #f8f9fa !important;
      }
      pre {
        font-size: 0.8rem;
      }
      code {
        font-size: 0.8rem;
      }
    `,
  ],
})
export class DebugAuthComponent {
  isLoggedIn = false;
  hasToken = false;
  tokenPreview = '';
  allCookies = '';
  debugOutput: Array<{
    timestamp: string;
    type: 'info' | 'success' | 'error';
    title: string;
    message: string;
    data?: any;
  }> = [];

  constructor(
    private authService: AuthService,
    private http: HttpClient,
  ) {
    this.updateState();
  }

  checkAuthState(): void {
    this.addDebugOutput(
      'info',
      'Checking Authentication State',
      'Gathering current authentication information...',
    );

    this.updateState();

    const token = localStorage.getItem('auth_token');
    const isAuthenticated = this.authService.isLoggedIn();

    this.addDebugOutput(
      'info',
      'Authentication Status',
      `Authenticated: ${isAuthenticated}, Token exists: ${!!token}`,
      {
        isAuthenticated,
        tokenExists: !!token,
        tokenLength: token?.length || 0,
        tokenExpiry: this.getTokenExpiry(token),
      },
    );
  }

  async testRefresh(): Promise<void> {
    this.addDebugOutput(
      'info',
      'Testing Refresh Token',
      'Attempting to refresh authentication token...',
    );

    try {
      console.log('🔧 DEBUG: Manually triggering refresh token...');

      // Call the refresh method from auth service
      const result = await this.authService.refreshToken().toPromise();

      this.addDebugOutput(
        'success',
        'Refresh Token Success',
        'Token refresh completed successfully',
        result,
      );

      this.updateState();
    } catch (error: any) {
      console.error('🔧 DEBUG: Refresh token failed:', error);

      this.addDebugOutput(
        'error',
        'Refresh Token Failed',
        `Error: ${error.message || error}`,
        {
          error: error.message || error,
          status: error.status || 'unknown',
          statusText: error.statusText || 'unknown',
        },
      );
    }
  }

  checkCookies(): void {
    this.addDebugOutput(
      'info',
      'Checking Cookie Status',
      'Analyzing browser cookie information...',
    );

    // Get all visible cookies
    const cookies = document.cookie;
    this.allCookies = cookies || 'No visible cookies';

    // Note about HttpOnly cookies
    const cookieInfo = {
      visibleCookies: cookies.split(';').filter((c) => c.trim()).length,
      allCookiesString: cookies,
      note: 'HttpOnly cookies (like refreshToken) will not appear in document.cookie',
      checkNetworkTab:
        'Check browser Network tab to see if Cookie header is sent with requests',
    };

    this.addDebugOutput(
      'info',
      'Cookie Analysis',
      `Found ${cookieInfo.visibleCookies} visible cookies. Note: HttpOnly cookies won't show here.`,
      cookieInfo,
    );
  }

  async testCookieEndpoint(): Promise<void> {
    this.addDebugOutput(
      'info',
      'Testing Cookie Endpoint',
      'Calling backend test endpoint to check cookie reception...',
    );

    try {
      const response = await this.http
        .get<any>(`${environment.apiUrl}/api/auth/test-cookie`, {
          withCredentials: true,
        })
        .toPromise();

      this.addDebugOutput(
        'success',
        'Cookie Endpoint Test Success',
        `Backend received cookies successfully`,
        response,
      );
    } catch (error: any) {
      console.error('🔧 DEBUG: Cookie endpoint test failed:', error);

      this.addDebugOutput(
        'error',
        'Cookie Endpoint Test Failed',
        `Error: ${error.message || error}`,
        {
          error: error.message || error,
          status: error.status || 'unknown',
          statusText: error.statusText || 'unknown',
        },
      );
    }
  }

  clearAll(): void {
    this.addDebugOutput(
      'info',
      'Clearing All Authentication Data',
      'Removing all authentication data...',
    );

    // Clear localStorage
    localStorage.removeItem('auth_token');

    // Try to clear cookies (note: can't clear HttpOnly cookies from client-side)
    const cookies = document.cookie.split(';');
    cookies.forEach((cookie) => {
      const eqPos = cookie.indexOf('=');
      const name = eqPos > -1 ? cookie.substr(0, eqPos).trim() : cookie.trim();
      if (name) {
        document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
        document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=localhost`;
      }
    });

    this.addDebugOutput(
      'success',
      'Cleared Authentication Data',
      'Removed tokens from localStorage. Note: HttpOnly cookies must be cleared by the server.',
    );

    this.updateState();
  }

  clearDebugOutput(): void {
    this.debugOutput = [];
  }

  private updateState(): void {
    const token = localStorage.getItem('auth_token');
    this.hasToken = !!token;
    this.isLoggedIn = this.authService.isLoggedIn();
    this.tokenPreview = token ? `${token.substring(0, 20)}...` : '';
    this.allCookies = document.cookie || 'No cookies visible';
  }

  private addDebugOutput(
    type: 'info' | 'success' | 'error',
    title: string,
    message: string,
    data?: any,
  ): void {
    const timestamp = new Date().toLocaleTimeString();
    this.debugOutput.unshift({ timestamp, type, title, message, data });

    // Also log to console
    const emoji = type === 'error' ? '❌' : type === 'success' ? '✅' : 'ℹ️';
    console.log(`${emoji} ${title}: ${message}`, data || '');
  }

  private getTokenExpiry(token: string | null): string {
    if (!token) return 'No token';

    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      const exp = payload.exp;
      if (exp) {
        const expDate = new Date(exp * 1000);
        return expDate.toLocaleString();
      }
    } catch (error) {
      return 'Unable to parse token';
    }

    return 'No expiry found';
  }

  formatData(data: any): string {
    return JSON.stringify(data, null, 2);
  }
}
