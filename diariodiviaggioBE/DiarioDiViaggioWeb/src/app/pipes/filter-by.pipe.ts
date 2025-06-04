import { Pipe, PipeTransform } from '@angular/core';

@Pipe({
  name: 'filterBy',
  pure: false
})
export class FilterByPipe implements PipeTransform {
  transform<T extends Record<string, any>>(items: T[], filter: { [key: string]: any }): T[] {
    if (!items || !filter) {
      return items;
    }
    
    return items.filter(item => {
      const keys = Object.keys(filter);
      return keys.every(key => {
        if (Object.prototype.hasOwnProperty.call(item, key)) {
          return item[key] === filter[key];
        }
        return true;
      });
    });
  }
}
