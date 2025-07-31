import { Component } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';

@Component({
  selector: 'app-confirm-dialog',
  templateUrl: './confirm-dialog.component.html',
  styleUrls: ['./confirm-dialog.component.scss']
})
export class ConfirmDialogComponent {
  title: string = 'Confirm';
  message: string = 'Are you sure?';
  confirmButtonText: string = 'Confirm';
  cancelButtonText: string = 'Cancel';

  constructor(public activeModal: NgbActiveModal) { }

  onCancel(): void {
    this.activeModal.dismiss(false);
  }

  onConfirm(): void {
    this.activeModal.close(true);
  }
}
