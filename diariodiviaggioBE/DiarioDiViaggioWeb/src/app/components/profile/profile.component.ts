import { Component, OnInit } from '@angular/core';
import { ProfileService, UserProfile, UpdateUserProfileRequest } from '../../services/profile.service';
import { AuthService } from '../../services/auth.service';
import { NotificationService } from '../../services/notification.service';

@Component({
  selector: 'app-profile',
  templateUrl: './profile.component.html',
  styleUrls: ['./profile.component.scss']
})
export class ProfileComponent implements OnInit {
  profile: UserProfile | null = null;
  loading = true;
  saving = false;
  
  // Form fields
  username = '';
  selectedFile: File | null = null;
  imagePreview: string | null = null;

  constructor(
    private profileService: ProfileService,
    private authService: AuthService,
    private notificationService: NotificationService
  ) { }

  ngOnInit(): void {
    this.loadProfile();
  }

  loadProfile(): void {
    this.loading = true;
    this.profileService.getProfile().subscribe({
      next: (profile) => {
        this.profile = profile;
        this.username = profile.username;
        this.imagePreview = profile.profileImageBase64 ? 
          `data:image/jpeg;base64,${profile.profileImageBase64}` : null;
        this.loading = false;
      },
      error: (error) => {
        this.notificationService.showError('Failed to load profile');
        this.loading = false;
      }
    });
  }

  onFileSelected(event: any): void {
    const file = event.target.files[0];
    if (file) {
      // Validate file type
      if (!file.type.startsWith('image/')) {
        this.notificationService.showError('Please select a valid image file');
        return;
      }
      
      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        this.notificationService.showError('Image size must be less than 5MB');
        return;
      }

      this.selectedFile = file;
      
      // Create preview
      const reader = new FileReader();
      reader.onload = (e) => {
        this.imagePreview = e.target?.result as string;
      };
      reader.readAsDataURL(file);
    }
  }

  async saveProfile(): Promise<void> {
    if (!this.profile) return;

    this.saving = true;
    
    try {
      let profileImageBase64: string | undefined;
      
      if (this.selectedFile) {
        profileImageBase64 = await this.convertFileToBase64(this.selectedFile);
        // Remove the data URL prefix
        profileImageBase64 = profileImageBase64.split(',')[1];
      }

      const request: UpdateUserProfileRequest = {
        username: this.username,
        profileImageBase64: profileImageBase64
      };

      this.profileService.updateProfile(request).subscribe({
        next: (updatedProfile) => {
          this.profile = updatedProfile;
          this.imagePreview = updatedProfile.profileImageBase64 ? 
            `data:image/jpeg;base64,${updatedProfile.profileImageBase64}` : null;
          
          // Update the current user in AuthService
          this.authService.updateCurrentUser({
            username: updatedProfile.username,
            email: updatedProfile.email,
            profileImageBase64: updatedProfile.profileImageBase64
          });
          
          this.notificationService.showSuccess('Profile updated successfully');
          this.selectedFile = null;
          this.saving = false;
        },
        error: (error) => {
          this.notificationService.showError(error.error?.message || 'Failed to update profile');
          this.saving = false;
        }
      });
    } catch (error) {
      this.notificationService.showError('Failed to process image');
      this.saving = false;
    }
  }

  removeProfileImage(): void {
    this.profileService.deleteProfileImage().subscribe({
      next: () => {
        if (this.profile) {
          this.profile.profileImageBase64 = undefined;
        }
        this.imagePreview = null;
        this.selectedFile = null;
        
        // Update the current user in AuthService
        this.authService.updateCurrentUser({
          username: this.profile?.username || '',
          email: this.profile?.email || '',
          profileImageBase64: undefined
        });
        
        this.notificationService.showSuccess('Profile image removed successfully');
      },
      error: (error) => {
        this.notificationService.showError('Failed to remove profile image');
      }
    });
  }

  private convertFileToBase64(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = error => reject(error);
    });
  }
}
