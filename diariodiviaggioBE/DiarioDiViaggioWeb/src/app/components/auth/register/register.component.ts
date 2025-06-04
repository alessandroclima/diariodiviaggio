import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AuthService, RegisterRequest } from '../../../services/auth.service';

@Component({
  selector: 'app-register',
  templateUrl: './register.component.html',
  styleUrls: ['./register.component.scss']
})
export class RegisterComponent implements OnInit {
  registerForm!: FormGroup;
  isLoading = false;
  hidePassword = true;

  constructor(
    private fb: FormBuilder,
    private authService: AuthService,
    private router: Router,
    private snackBar: MatSnackBar
  ) { }

  ngOnInit(): void {
    this.registerForm = this.fb.group({
      username: ['', [Validators.required, Validators.minLength(3)]],
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(6)]]
    });

    // Redirect if already logged in
    if (this.authService.isLoggedIn()) {
      this.router.navigate(['/trips']);
    }
  }

  onSubmit(): void {
    if (this.registerForm.invalid) return;

    this.isLoading = true;
    const registerRequest: RegisterRequest = this.registerForm.value;

    this.authService.register(registerRequest)
      .subscribe({
        next: () => {
          this.snackBar.open('Registrazione completata con successo!', 'Chiudi', {
            duration: 5000,
          });
          this.router.navigate(['/trips']);
        },
        error: (error) => {
          this.snackBar.open(error.error?.message || 'Si è verificato un errore durante la registrazione', 'Chiudi', {
            duration: 5000,
          });
          this.isLoading = false;
        }
      });
  }
}
