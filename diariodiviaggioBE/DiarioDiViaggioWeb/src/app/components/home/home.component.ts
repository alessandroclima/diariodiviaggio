import { Component } from '@angular/core';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-home',
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.scss']
})
export class HomeComponent {
  
  constructor(private authService: AuthService) { }
  
  isLoggedIn(): boolean {
    return this.authService.isLoggedIn();
  }
}
