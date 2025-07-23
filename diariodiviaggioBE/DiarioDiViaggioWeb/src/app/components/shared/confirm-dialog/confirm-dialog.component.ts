import { Component, Input, Output, EventEmitter } from '@angular/core';

export interface ConfirmDialogData {
  title: string;
  message: string;
  confirmButtonText: string;
  cancelButtonText?: string;
}

@Component({
  selector: 'app-confirm-dialog',
  templateUrl: './confirm-dialog.component.html',
  styleUrls: ['./confirm-dialog.component.scss']
})
export class ConfirmDialogComponent {
  @Input() data: ConfirmDialogData = {
    title: 'Conferma',
    message: 'Sei sicuro?',
    confirmButtonText: 'Conferma',
    cancelButtonText: 'Annulla'
  };
  @Input() isVisible: boolean = false;
  @Output() confirmed = new EventEmitter<boolean>();
  @Output() visibilityChange = new EventEmitter<boolean>();

  onCancel(): void {
    this.isVisible = false;
    this.visibilityChange.emit(false);
    this.confirmed.emit(false);
  }

  onConfirm(): void {
    this.isVisible = false;
    this.visibilityChange.emit(false);
    this.confirmed.emit(true);
  }

  onBackdropClick(event: Event): void {
    if (event.target === event.currentTarget) {
      this.onCancel();
    }
  }
}
