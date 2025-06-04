import { ComponentFixture, TestBed } from '@angular/core/testing';

import { LuggageListComponent } from './luggage-list.component';

describe('LuggageListComponent', () => {
  let component: LuggageListComponent;
  let fixture: ComponentFixture<LuggageListComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      declarations: [LuggageListComponent]
    });
    fixture = TestBed.createComponent(LuggageListComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
