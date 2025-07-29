import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService, PasswordReset } from '../../services/auth.service';

@Component({
  selector: 'app-reset-password',
  templateUrl: './reset-password.component.html',
  styleUrls: ['./reset-password.component.scss']
})
export class ResetPasswordComponent implements OnInit {
  resetPasswordForm: FormGroup;
  isLoading = false;
  message = '';
  messageType: 'success' | 'error' = 'success';
  token = '';
  showPassword = false;
  showConfirmPassword = false;

  constructor(
    private formBuilder: FormBuilder,
    private authService: AuthService,
    private router: Router,
    private route: ActivatedRoute
  ) {
    this.resetPasswordForm = this.formBuilder.group({
      newPassword: ['', [Validators.required, Validators.minLength(6)]],
      confirmPassword: ['', [Validators.required]]
    }, { validators: this.passwordMatchValidator });
  }

  ngOnInit(): void {
    // Get token from query parameters
    this.token = this.route.snapshot.queryParams['token'] || '';
    
    if (!this.token) {
      this.message = 'Invalid or missing reset token. Please request a new password reset.';
      this.messageType = 'error';
    }
  }

  passwordMatchValidator(form: FormGroup) {
    const password = form.get('newPassword');
    const confirmPassword = form.get('confirmPassword');
    
    if (password && confirmPassword && password.value !== confirmPassword.value) {
      confirmPassword.setErrors({ passwordMismatch: true });
      return { passwordMismatch: true };
    }
    
    return null;
  }

  onSubmit(): void {
    if (this.resetPasswordForm.valid && !this.isLoading && this.token) {
      this.isLoading = true;
      this.message = '';

      const resetData: PasswordReset = {
        token: this.token,
        newPassword: this.resetPasswordForm.value.newPassword
      };

      this.authService.resetPassword(resetData).subscribe({
        next: (response) => {
          this.message = response.message;
          this.messageType = 'success';
          this.isLoading = false;
          
          // Redirect to login after 3 seconds
          setTimeout(() => {
            this.router.navigate(['/login'], { 
              queryParams: { message: 'Password reset successful. Please log in with your new password.' } 
            });
          }, 3000);
        },
        error: (error) => {
          this.message = error.error?.message || 'An error occurred. Please try again.';
          this.messageType = 'error';
          this.isLoading = false;
        }
      });
    }
  }

  togglePasswordVisibility(): void {
    this.showPassword = !this.showPassword;
  }

  toggleConfirmPasswordVisibility(): void {
    this.showConfirmPassword = !this.showConfirmPassword;
  }

  goToLogin(): void {
    this.router.navigate(['/login']);
  }

  requestNewToken(): void {
    this.router.navigate(['/forgot-password']);
  }
}
