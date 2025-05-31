using DiarioDiViaggioApi.DTOs;

namespace DiarioDiViaggioApi.Services;

public interface ILuggageService
{
    Task<LuggageResponseDto> CreateLuggageAsync(int tripId, int userId, CreateLuggageDto createDto);
    Task<LuggageResponseDto> UpdateLuggageAsync(int luggageId, int userId, UpdateLuggageDto updateDto);
    Task<LuggageResponseDto> GetLuggageByIdAsync(int luggageId, int userId);
    Task<List<LuggageResponseDto>> GetTripLuggagesAsync(int tripId, int userId);
    Task DeleteLuggageAsync(int luggageId, int userId);
    
    // Luggage Item operations
    Task<LuggageItemResponseDto> AddLuggageItemAsync(int luggageId, int userId, CreateLuggageItemDto createDto);
    Task<LuggageItemResponseDto> UpdateLuggageItemAsync(int itemId, int userId, UpdateLuggageItemDto updateDto);
    Task<LuggageItemResponseDto> GetLuggageItemByIdAsync(int itemId, int userId);
    Task DeleteLuggageItemAsync(int itemId, int userId);
}
