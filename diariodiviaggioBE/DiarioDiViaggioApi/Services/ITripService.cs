using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Models;

namespace DiarioDiViaggioApi.Services;

public interface ITripService
{
    Task<TripResponseDto> CreateTripAsync(int userId, CreateTripDto createTripDto);
    Task<TripResponseDto> UpdateTripAsync(int tripId, int userId, UpdateTripDto updateTripDto);
    Task<TripResponseDto> GetTripByIdAsync(int tripId, int userId);
    Task<List<TripResponseDto>> GetUserTripsAsync(int userId);
    Task DeleteTripAsync(int tripId, int userId);
    Task<TripResponseDto> ShareTripAsync(int tripId, int userId);
    Task<TripResponseDto> JoinTripByCodeAsync(string shareCode, int userId);
}
