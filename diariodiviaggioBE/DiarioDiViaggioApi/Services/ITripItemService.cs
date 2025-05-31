using DiarioDiViaggioApi.DTOs;

namespace DiarioDiViaggioApi.Services;

public interface ITripItemService
{
    Task<TripItemResponseDto> CreateTripItemAsync(int tripId, int userId, CreateTripItemDto createTripItemDto);
    Task<TripItemResponseDto> UpdateTripItemAsync(int itemId, int userId, UpdateTripItemDto updateTripItemDto);
    Task<TripItemResponseDto> GetTripItemByIdAsync(int itemId, int userId);
    Task<List<TripItemResponseDto>> GetTripItemsAsync(int tripId, int userId);
    Task DeleteTripItemAsync(int itemId, int userId);
    Task<string> SaveImageAsync(int tripId, IFormFile image);
}
