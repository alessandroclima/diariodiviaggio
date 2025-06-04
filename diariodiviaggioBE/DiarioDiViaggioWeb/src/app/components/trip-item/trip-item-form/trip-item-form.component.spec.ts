import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TripItemFormComponent } from './trip-item-form.component';

describe('TripItemFormComponent', () => {
  let component: TripItemFormComponent;
  let fixture: ComponentFixture<TripItemFormComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      declarations: [TripItemFormComponent]
    });
    fixture = TestBed.createComponent(TripItemFormComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
