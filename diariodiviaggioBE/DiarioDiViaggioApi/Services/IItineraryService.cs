using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Models;

namespace DiarioDiViaggioApi.Services
{
    public interface IItineraryService
    {
        Task<ItineraryDto> CreateItineraryAsync(CreateItineraryDto createItineraryDto, int userId);
        Task<ItineraryDto?> GetItineraryByIdAsync(int id, int userId);
        Task<List<ItineraryDto>> GetItinerariesByTripAsync(int tripId, int userId);
        Task<TripItineraryCalendarDto?> GetTripItineraryCalendarAsync(int tripId, int userId);
        Task<ItineraryDto?> UpdateItineraryAsync(int id, UpdateItineraryDto updateItineraryDto, int userId);
        Task<bool> DeleteItineraryAsync(int id, int userId);
        Task<List<ItineraryDto>> GetItinerariesByDateAsync(int tripId, DateTime date, int userId);
    }
}
