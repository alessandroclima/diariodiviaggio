using Microsoft.EntityFrameworkCore;
using DiarioDiViaggioApi.Data;
using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Models;

namespace DiarioDiViaggioApi.Services;

public class TripService : ITripService
{
    private readonly ApplicationDbContext _context;

    public TripService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<TripResponseDto> CreateTripAsync(int userId, CreateTripDto createTripDto)
    {
        var trip = new Trip
        {
            Title = createTripDto.Title,
            Description = createTripDto.Description ?? "",
            StartDate = createTripDto.StartDate,
            EndDate = createTripDto.EndDate,
            OwnerId = userId,
            ShareCode = GenerateShareCode()
        };

        _context.Trips.Add(trip);
        await _context.SaveChangesAsync();

        return await GetTripResponseDto(trip);
    }

    public async Task<TripResponseDto> UpdateTripAsync(int tripId, int userId, UpdateTripDto updateTripDto)
    {
        var trip = await _context.Trips
            .FirstOrDefaultAsync(t => t.Id == tripId && t.OwnerId == userId);

        if (trip == null)
        {
            throw new InvalidOperationException("Trip not found or you don't have permission to update it");
        }

        trip.Title = updateTripDto.Title;
        trip.Description = updateTripDto.Description ?? "";
        trip.StartDate = updateTripDto.StartDate;
        trip.EndDate = updateTripDto.EndDate;

        await _context.SaveChangesAsync();

        return await GetTripResponseDto(trip);
    }

    public async Task<TripResponseDto> GetTripByIdAsync(int tripId, int userId)
    {
        var trip = await _context.Trips
            .Include(t => t.SharedWithUsers)
            .ThenInclude(ts => ts.User)
            .Include(t => t.Owner)
            .FirstOrDefaultAsync(t => t.Id == tripId && 
                (t.OwnerId == userId || t.SharedWithUsers.Any(ts => ts.UserId == userId)));

        if (trip == null)
        {
            throw new InvalidOperationException("Trip not found or you don't have access to it");
        }

        return await GetTripResponseDto(trip);
    }

    public async Task<List<TripResponseDto>> GetUserTripsAsync(int userId)
    {
        var trips = await _context.Trips
            .Include(t => t.SharedWithUsers)
            .ThenInclude(ts => ts.User)
            .Include(t => t.Owner)
            .Where(t => t.OwnerId == userId || t.SharedWithUsers.Any(ts => ts.UserId == userId))
            .ToListAsync();

        var tripDtos = new List<TripResponseDto>();
        foreach (var trip in trips)
        {
            tripDtos.Add(await GetTripResponseDto(trip));
        }

        return tripDtos;
    }

    public async Task DeleteTripAsync(int tripId, int userId)
    {
        var trip = await _context.Trips
            .FirstOrDefaultAsync(t => t.Id == tripId && t.OwnerId == userId);

        if (trip == null)
        {
            throw new InvalidOperationException("Trip not found or you don't have permission to delete it");
        }

        _context.Trips.Remove(trip);
        await _context.SaveChangesAsync();
    }

    public async Task<TripResponseDto> ShareTripAsync(int tripId, int userId)
    {
        var trip = await _context.Trips
            .Include(t => t.SharedWithUsers)
            .FirstOrDefaultAsync(t => t.Id == tripId && t.OwnerId == userId);

        if (trip == null)
        {
            throw new InvalidOperationException("Trip not found or you don't have permission to share it");
        }

        // Generate new share code if it doesn't exist
        if (string.IsNullOrEmpty(trip.ShareCode))
        {
            trip.ShareCode = GenerateShareCode();
            await _context.SaveChangesAsync();
        }

        return await GetTripResponseDto(trip);
    }

    public async Task<TripResponseDto> JoinTripByCodeAsync(string shareCode, int userId)
    {
        var trip = await _context.Trips
            .Include(t => t.SharedWithUsers)
            .FirstOrDefaultAsync(t => t.ShareCode == shareCode);

        if (trip == null)
        {
            throw new InvalidOperationException("Invalid share code");
        }

        if (trip.OwnerId == userId || trip.SharedWithUsers.Any(ts => ts.UserId == userId))
        {
            throw new InvalidOperationException("You already have access to this trip");
        }

        var tripShare = new TripShare
        {
            TripId = trip.Id,
            UserId = userId
        };

        _context.TripShares.Add(tripShare);
        await _context.SaveChangesAsync();

        return await GetTripResponseDto(trip);
    }

    private static string GenerateShareCode()
    {
        const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var random = new Random();
        return new string(Enumerable.Repeat(chars, 8)
            .Select(s => s[random.Next(s.Length)]).ToArray());
    }

    private async Task<TripResponseDto> GetTripResponseDto(Trip trip)
    {
        await _context.Entry(trip).Reference(t => t.Owner).LoadAsync();
        await _context.Entry(trip).Collection(t => t.SharedWithUsers).LoadAsync();
        foreach (var share in trip.SharedWithUsers)
        {
            await _context.Entry(share).Reference(ts => ts.User).LoadAsync();
        }

        return new TripResponseDto
        {
            Id = trip.Id,
            Title = trip.Title,
            Description = trip.Description,
            StartDate = trip.StartDate,
            EndDate = trip.EndDate,
            ShareCode = trip.ShareCode,
            OwnerUsername = trip.Owner.Username,
            SharedWithUsernames = trip.SharedWithUsers.Select(ts => ts.User.Username).ToList()
        };
    }
}
