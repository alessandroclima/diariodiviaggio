using Microsoft.EntityFrameworkCore;
using DiarioDiViaggioApi.Data;
using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Models;

namespace DiarioDiViaggioApi.Services;

public class TripItemService : ITripItemService
{
    private readonly ApplicationDbContext _context;
    private readonly IWebHostEnvironment _environment;

    public TripItemService(ApplicationDbContext context, IWebHostEnvironment environment)
    {
        _context = context;
        _environment = environment;
    }

    public async Task<TripItemResponseDto> CreateTripItemAsync(int tripId, int userId, CreateTripItemDto createDto)
    {
        var trip = await _context.Trips
            .FirstOrDefaultAsync(t => t.Id == tripId && 
                (t.OwnerId == userId || t.SharedWithUsers.Any(ts => ts.UserId == userId)));

        if (trip == null)
        {
            throw new InvalidOperationException("Trip not found or you don't have access to it");
        }

        byte[]? imageData = null;
        if (createDto.Image != null)
        {
            imageData = await ConvertImageToByteArrayAsync(createDto.Image);
        }

        var tripItem = new TripItem
        {
            TripId = tripId,
            Title = createDto.Title,
            Description = createDto.Description ?? "",
            Type = Enum.Parse<ItemType>(createDto.Type),
            Location = createDto.Location,
            Rating = createDto.Rating,
            ImageData = imageData,
            CreatedById = userId
        };

        _context.TripItems.Add(tripItem);
        await _context.SaveChangesAsync();

        return await GetTripItemResponseDto(tripItem);
    }

    public async Task<TripItemResponseDto> UpdateTripItemAsync(int itemId, int userId, UpdateTripItemDto updateDto)
    {
        var tripItem = await _context.TripItems
            .Include(ti => ti.Trip)
            .FirstOrDefaultAsync(ti => ti.Id == itemId);

        if (tripItem == null || !await HasAccessToTrip(tripItem.TripId, userId))
        {
            throw new InvalidOperationException("Trip item not found or you don't have access to it");
        }

        tripItem.Title = updateDto.Title;
        tripItem.Description = updateDto.Description ?? tripItem.Description;
        tripItem.Location = updateDto.Location ?? tripItem.Location;
        tripItem.Rating = updateDto.Rating ?? tripItem.Rating;

        // Handle image updates
        if (updateDto.RemoveImage)
        {
            tripItem.ImageData = null;
        }
        else if (updateDto.Image != null)
        {
            tripItem.ImageData = await ConvertImageToByteArrayAsync(updateDto.Image);
        }

        await _context.SaveChangesAsync();

        return await GetTripItemResponseDto(tripItem);
    }

    public async Task<TripItemResponseDto> GetTripItemByIdAsync(int itemId, int userId)
    {
        var tripItem = await _context.TripItems
            .Include(ti => ti.Trip)
            .Include(ti => ti.CreatedBy)
            .FirstOrDefaultAsync(ti => ti.Id == itemId);

        if (tripItem == null || !await HasAccessToTrip(tripItem.TripId, userId))
        {
            throw new InvalidOperationException("Trip item not found or you don't have access to it");
        }

        return await GetTripItemResponseDto(tripItem);
    }

    public async Task<List<TripItemResponseDto>> GetTripItemsAsync(int tripId, int userId)
    {
        if (!await HasAccessToTrip(tripId, userId))
        {
            throw new InvalidOperationException("Trip not found or you don't have access to it");
        }

        var tripItems = await _context.TripItems
            .Include(ti => ti.CreatedBy)
            .Where(ti => ti.TripId == tripId)
            .OrderByDescending(ti => ti.CreatedAt)
            .ToListAsync();

        var tripItemDtos = new List<TripItemResponseDto>();
        foreach (var item in tripItems)
        {
            tripItemDtos.Add(await GetTripItemResponseDto(item));
        }

        return tripItemDtos;
    }

    public async Task DeleteTripItemAsync(int itemId, int userId)
    {
        var tripItem = await _context.TripItems
            .Include(ti => ti.Trip)
            .FirstOrDefaultAsync(ti => ti.Id == itemId);

        if (tripItem == null || !await HasAccessToTrip(tripItem.TripId, userId))
        {
            throw new InvalidOperationException("Trip item not found or you don't have access to it");
        }

        // No need to delete files since image is stored in database
        _context.TripItems.Remove(tripItem);
        await _context.SaveChangesAsync();
    }

    public async Task<byte[]> ConvertImageToByteArrayAsync(IFormFile image)
    {
        using (var memoryStream = new MemoryStream())
        {
            await image.CopyToAsync(memoryStream);
            return memoryStream.ToArray();
        }
    }

    private async Task<bool> HasAccessToTrip(int tripId, int userId)
    {
        return await _context.Trips
            .AnyAsync(t => t.Id == tripId && 
                (t.OwnerId == userId || t.SharedWithUsers.Any(ts => ts.UserId == userId)));
    }

    private async Task<TripItemResponseDto> GetTripItemResponseDto(TripItem item)
    {
        await _context.Entry(item).Reference(ti => ti.CreatedBy).LoadAsync();

        string? imageUrl = null;
        if (item.ImageData != null)
        {
            var base64String = Convert.ToBase64String(item.ImageData);
            imageUrl = base64String;
        }

        return new TripItemResponseDto
        {
            Id = item.Id,
            Title = item.Title,
            Description = item.Description,
            Type = item.Type.ToString(),
            Location = item.Location,
            Rating = item.Rating,
            ImageUrl = imageUrl,
            CreatedAt = item.CreatedAt,
            CreatedByUsername = item.CreatedBy.Username
        };
    }
}
