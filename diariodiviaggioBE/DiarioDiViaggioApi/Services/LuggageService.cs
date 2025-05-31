using Microsoft.EntityFrameworkCore;
using DiarioDiViaggioApi.Data;
using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Models;

namespace DiarioDiViaggioApi.Services;

public class LuggageService : ILuggageService
{
    private readonly ApplicationDbContext _context;

    public LuggageService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<LuggageResponseDto> CreateLuggageAsync(int tripId, int userId, CreateLuggageDto createDto)
    {
        if (!await HasAccessToTrip(tripId, userId))
        {
            throw new InvalidOperationException("Trip not found or you don't have access to it");
        }

        var luggage = new Luggage
        {
            Name = createDto.Name,
            Description = createDto.Description ?? "",
            TripId = tripId
        };

        _context.Luggages.Add(luggage);
        await _context.SaveChangesAsync();

        return await GetLuggageResponseDto(luggage);
    }

    public async Task<LuggageResponseDto> UpdateLuggageAsync(int luggageId, int userId, UpdateLuggageDto updateDto)
    {
        var luggage = await _context.Luggages
            .Include(l => l.Trip)
            .FirstOrDefaultAsync(l => l.Id == luggageId);

        if (luggage == null || !await HasAccessToTrip(luggage.TripId, userId))
        {
            throw new InvalidOperationException("Luggage not found or you don't have access to it");
        }

        luggage.Name = updateDto.Name;
        luggage.Description = updateDto.Description ?? luggage.Description;

        await _context.SaveChangesAsync();

        return await GetLuggageResponseDto(luggage);
    }

    public async Task<LuggageResponseDto> GetLuggageByIdAsync(int luggageId, int userId)
    {
        var luggage = await _context.Luggages
            .Include(l => l.Trip)
            .Include(l => l.Items)
            .FirstOrDefaultAsync(l => l.Id == luggageId);

        if (luggage == null || !await HasAccessToTrip(luggage.TripId, userId))
        {
            throw new InvalidOperationException("Luggage not found or you don't have access to it");
        }

        return await GetLuggageResponseDto(luggage);
    }

    public async Task<List<LuggageResponseDto>> GetTripLuggagesAsync(int tripId, int userId)
    {
        if (!await HasAccessToTrip(tripId, userId))
        {
            throw new InvalidOperationException("Trip not found or you don't have access to it");
        }

        var luggages = await _context.Luggages
            .Include(l => l.Items)
            .Where(l => l.TripId == tripId)
            .ToListAsync();

        var luggageDtos = new List<LuggageResponseDto>();
        foreach (var luggage in luggages)
        {
            luggageDtos.Add(await GetLuggageResponseDto(luggage));
        }

        return luggageDtos;
    }

    public async Task DeleteLuggageAsync(int luggageId, int userId)
    {
        var luggage = await _context.Luggages
            .Include(l => l.Trip)
            .FirstOrDefaultAsync(l => l.Id == luggageId);

        if (luggage == null || !await HasAccessToTrip(luggage.TripId, userId))
        {
            throw new InvalidOperationException("Luggage not found or you don't have access to it");
        }

        _context.Luggages.Remove(luggage);
        await _context.SaveChangesAsync();
    }

    public async Task<LuggageItemResponseDto> AddLuggageItemAsync(int luggageId, int userId, CreateLuggageItemDto createDto)
    {
        var luggage = await _context.Luggages
            .Include(l => l.Trip)
            .FirstOrDefaultAsync(l => l.Id == luggageId);

        if (luggage == null || !await HasAccessToTrip(luggage.TripId, userId))
        {
            throw new InvalidOperationException("Luggage not found or you don't have access to it");
        }

        var item = new LuggageItem
        {
            Name = createDto.Name,
            Notes = createDto.Notes,
            Quantity = createDto.Quantity,
            LuggageId = luggageId
        };

        _context.LuggageItems.Add(item);
        await _context.SaveChangesAsync();

        return GetLuggageItemResponseDto(item);
    }

    public async Task<LuggageItemResponseDto> UpdateLuggageItemAsync(int itemId, int userId, UpdateLuggageItemDto updateDto)
    {
        var item = await _context.LuggageItems
            .Include(li => li.Luggage)
            .ThenInclude(l => l.Trip)
            .FirstOrDefaultAsync(li => li.Id == itemId);

        if (item == null || !await HasAccessToTrip(item.Luggage.TripId, userId))
        {
            throw new InvalidOperationException("Item not found or you don't have access to it");
        }

        item.Name = updateDto.Name;
        item.Notes = updateDto.Notes;
        item.Quantity = updateDto.Quantity;
        item.IsPacked = updateDto.IsPacked;

        await _context.SaveChangesAsync();

        return GetLuggageItemResponseDto(item);
    }

    public async Task<LuggageItemResponseDto> GetLuggageItemByIdAsync(int itemId, int userId)
    {
        var item = await _context.LuggageItems
            .Include(li => li.Luggage)
            .ThenInclude(l => l.Trip)
            .FirstOrDefaultAsync(li => li.Id == itemId);

        if (item == null || !await HasAccessToTrip(item.Luggage.TripId, userId))
        {
            throw new InvalidOperationException("Item not found or you don't have access to it");
        }

        return GetLuggageItemResponseDto(item);
    }

    public async Task DeleteLuggageItemAsync(int itemId, int userId)
    {
        var item = await _context.LuggageItems
            .Include(li => li.Luggage)
            .ThenInclude(l => l.Trip)
            .FirstOrDefaultAsync(li => li.Id == itemId);

        if (item == null || !await HasAccessToTrip(item.Luggage.TripId, userId))
        {
            throw new InvalidOperationException("Item not found or you don't have access to it");
        }

        _context.LuggageItems.Remove(item);
        await _context.SaveChangesAsync();
    }

    private async Task<bool> HasAccessToTrip(int tripId, int userId)
    {
        return await _context.Trips
            .AnyAsync(t => t.Id == tripId && 
                (t.OwnerId == userId || t.SharedWithUsers.Any(ts => ts.UserId == userId)));
    }

    private async Task<LuggageResponseDto> GetLuggageResponseDto(Luggage luggage)
    {
        await _context.Entry(luggage).Collection(l => l.Items).LoadAsync();

        return new LuggageResponseDto
        {
            Id = luggage.Id,
            Name = luggage.Name,
            Description = luggage.Description,
            Items = luggage.Items.Select(GetLuggageItemResponseDto).ToList()
        };
    }

    private static LuggageItemResponseDto GetLuggageItemResponseDto(LuggageItem item)
    {
        return new LuggageItemResponseDto
        {
            Id = item.Id,
            Name = item.Name,
            Notes = item.Notes,
            Quantity = item.Quantity,
            IsPacked = item.IsPacked
        };
    }
}
