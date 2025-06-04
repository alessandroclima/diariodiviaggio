import { Component, Input, OnInit } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Luggage, LuggageService, CreateLuggageRequest } from '../../../services/luggage.service';
import { ConfirmDialogComponent } from '../../shared/confirm-dialog/confirm-dialog.component';

@Component({
  selector: 'app-luggage-list',
  templateUrl: './luggage-list.component.html',
  styleUrls: ['./luggage-list.component.scss']
})
export class LuggageListComponent implements OnInit {
  @Input() tripId!: number;
  
  luggages: Luggage[] = [];
  loading = true;
  error = false;
  showAddForm = false;
  
  newLuggage: CreateLuggageRequest = {
    name: '',
    description: ''
  };

  constructor(
    private luggageService: LuggageService,
    private dialog: MatDialog,
    private snackBar: MatSnackBar
  ) { }

  ngOnInit(): void {
    this.loadLuggages();
  }

  loadLuggages(): void {
    this.loading = true;
    this.error = false;
    
    this.luggageService.getTripLuggages(this.tripId).subscribe({
      next: (luggages) => {
        this.luggages = luggages;
        this.loading = false;
      },
      error: (err) => {
        console.error('Error loading luggages:', err);
        this.loading = false;
        this.error = true;
        this.snackBar.open('Failed to load luggage lists', 'Close', { duration: 3000 });
      }
    });
  }

  toggleAddForm(): void {
    this.showAddForm = !this.showAddForm;
    if (this.showAddForm) {
      // Reset form
      this.newLuggage = {
        name: '',
        description: ''
      };
    }
  }

  createLuggage(): void {
    if (!this.newLuggage.name.trim()) {
      this.snackBar.open('Please provide a name for the luggage list', 'Close', { duration: 3000 });
      return;
    }

    this.luggageService.createLuggage(this.tripId, this.newLuggage).subscribe({
      next: (luggage) => {
        this.luggages.push(luggage);
        this.showAddForm = false;
        this.snackBar.open('Luggage list created successfully', 'Close', { duration: 3000 });
      },
      error: (err) => {
        console.error('Error creating luggage:', err);
        this.snackBar.open('Failed to create luggage list', 'Close', { duration: 3000 });
      }
    });
  }

  deleteLuggage(luggage: Luggage): void {
    const dialogRef = this.dialog.open(ConfirmDialogComponent, {
      width: '350px',
      data: {
        title: 'Delete Luggage',
        message: `Are you sure you want to delete "${luggage.name}"?`,
        confirmButtonText: 'Delete'
      }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.luggageService.deleteLuggage(luggage.id).subscribe({
          next: () => {
            this.luggages = this.luggages.filter(l => l.id !== luggage.id);
            this.snackBar.open('Luggage list deleted successfully', 'Close', { duration: 3000 });
          },
          error: (err) => {
            console.error('Error deleting luggage:', err);
            this.snackBar.open('Failed to delete luggage list', 'Close', { duration: 3000 });
          }
        });
      }
    });
  }

  getPackedItemsCount(items: any[]): number {
    return items.filter(item => item.isPacked).length;
  }

  getPackingProgress(items: any[]): number {
    if (!items || items.length === 0) return 0;
    return (this.getPackedItemsCount(items) / items.length) * 100;
  }
}
