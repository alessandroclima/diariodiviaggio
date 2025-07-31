using DiarioDiViaggioApi.Data;
using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Models;
using Microsoft.EntityFrameworkCore;

namespace DiarioDiViaggioApi.Services
{
    public class ItineraryService : IItineraryService
    {
        private readonly ApplicationDbContext _context;

        public ItineraryService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<ItineraryDto> CreateItineraryAsync(CreateItineraryDto createItineraryDto, int userId)
        {
            // Verify user has access to the trip
            var trip = await _context.Trips
                .FirstOrDefaultAsync(t => t.Id == createItineraryDto.TripId && 
                    (t.OwnerId == userId || t.SharedWithUsers.Any(s => s.UserId == userId)));

            if (trip == null)
            {
                throw new UnauthorizedAccessException("You don't have access to this trip.");
            }

            var itinerary = new Itinerary
            {
                TripId = createItineraryDto.TripId,
                Date = DateTime.SpecifyKind(createItineraryDto.Date.Date, DateTimeKind.Utc),  // Ensure date only, no time component
                Title = createItineraryDto.Title,
                Description = createItineraryDto.Description,
                ActivityType = createItineraryDto.ActivityType,
                Location = createItineraryDto.Location,
                TimeSlot = createItineraryDto.TimeSlot,
                Notes = createItineraryDto.Notes,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Itineraries.Add(itinerary);
            await _context.SaveChangesAsync();

            return MapToDto(itinerary);
        }

        public async Task<ItineraryDto?> GetItineraryByIdAsync(int id, int userId)
        {
            var itinerary = await _context.Itineraries
                .Include(i => i.Trip)
                .FirstOrDefaultAsync(i => i.Id == id && 
                    (i.Trip.OwnerId == userId || i.Trip.SharedWithUsers.Any(s => s.UserId == userId)));

            return itinerary != null ? MapToDto(itinerary) : null;
        }

        public async Task<List<ItineraryDto>> GetItinerariesByTripAsync(int tripId, int userId)
        {
            var itineraries = await _context.Itineraries
                .Include(i => i.Trip)
                .Where(i => i.TripId == tripId && 
                    (i.Trip.OwnerId == userId || i.Trip.SharedWithUsers.Any(s => s.UserId == userId)))
                .OrderBy(i => i.Date)
                .ThenBy(i => i.TimeSlot)
                .ToListAsync();

            return itineraries.Select(MapToDto).ToList();
        }

        public async Task<TripItineraryCalendarDto?> GetTripItineraryCalendarAsync(int tripId, int userId)
        {
            var trip = await _context.Trips
                .Include(t => t.Itineraries)
                .FirstOrDefaultAsync(t => t.Id == tripId && 
                    (t.OwnerId == userId || t.SharedWithUsers.Any(s => s.UserId == userId)));

            if (trip == null)
            {
                return null;
            }

            var calendar = new List<ItineraryCalendarDto>();
            var startDate = trip.StartDate.Date;
            var endDate = trip.EndDate?.Date ?? trip.StartDate.Date;

            // Generate calendar for all days in the trip
            for (var date = startDate; date <= endDate; date = date.AddDays(1))
            {
                var dayItineraries = trip.Itineraries
                    .Where(i => i.Date.Date == date)
                    .OrderBy(i => i.TimeSlot)
                    .Select(MapToDto)
                    .ToList();

                calendar.Add(new ItineraryCalendarDto
                {
                    Date = date,
                    Activities = dayItineraries
                });
            }

            return new TripItineraryCalendarDto
            {
                TripId = trip.Id,
                TripTitle = trip.Title,
                StartDate = trip.StartDate,
                EndDate = trip.EndDate,
                Calendar = calendar
            };
        }

        public async Task<ItineraryDto?> UpdateItineraryAsync(int id, UpdateItineraryDto updateItineraryDto, int userId)
        {
            var itinerary = await _context.Itineraries
                .Include(i => i.Trip)
                .FirstOrDefaultAsync(i => i.Id == id && 
                    (i.Trip.OwnerId == userId || i.Trip.SharedWithUsers.Any(s => s.UserId == userId)));

            if (itinerary == null)
            {
                return null;
            }

            itinerary.Date = DateTime.SpecifyKind(updateItineraryDto.Date, DateTimeKind.Utc);
            itinerary.Title = updateItineraryDto.Title;
            itinerary.Description = updateItineraryDto.Description;
            itinerary.ActivityType = updateItineraryDto.ActivityType;
            itinerary.Location = updateItineraryDto.Location;
            itinerary.TimeSlot = updateItineraryDto.TimeSlot;
            itinerary.Notes = updateItineraryDto.Notes;
            itinerary.IsCompleted = updateItineraryDto.IsCompleted;
            itinerary.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return MapToDto(itinerary);
        }

        public async Task<bool> DeleteItineraryAsync(int id, int userId)
        {
            var itinerary = await _context.Itineraries
                .Include(i => i.Trip)
                .FirstOrDefaultAsync(i => i.Id == id && 
                    (i.Trip.OwnerId == userId || i.Trip.SharedWithUsers.Any(s => s.UserId == userId)));

            if (itinerary == null)
            {
                return false;
            }

            _context.Itineraries.Remove(itinerary);
            await _context.SaveChangesAsync();

            return true;
        }

        public async Task<List<ItineraryDto>> GetItinerariesByDateAsync(int tripId, DateTime date, int userId)
        {
            var itineraries = await _context.Itineraries
                .Include(i => i.Trip)
                .Where(i => i.TripId == tripId && 
                    i.Date.Date == date.Date &&
                    (i.Trip.OwnerId == userId || i.Trip.SharedWithUsers.Any(s => s.UserId == userId)))
                .OrderBy(i => i.TimeSlot)
                .ToListAsync();

            return itineraries.Select(MapToDto).ToList();
        }

        private static ItineraryDto MapToDto(Itinerary itinerary)
        {
            return new ItineraryDto
            {
                Id = itinerary.Id,
                TripId = itinerary.TripId,
                Date = itinerary.Date,
                Title = itinerary.Title,
                Description = itinerary.Description,
                ActivityType = itinerary.ActivityType,
                Location = itinerary.Location,
                TimeSlot = itinerary.TimeSlot,
                Notes = itinerary.Notes,
                IsCompleted = itinerary.IsCompleted,
                CreatedAt = itinerary.CreatedAt,
                UpdatedAt = itinerary.UpdatedAt
            };
        }
    }
}
