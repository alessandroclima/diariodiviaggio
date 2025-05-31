using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Services;

namespace DiarioDiViaggioApi.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class TripController : ControllerBase
{
    private readonly ITripService _tripService;

    public TripController(ITripService tripService)
    {
        _tripService = tripService;
    }

    private int GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null)
        {
            throw new UnauthorizedAccessException();
        }
        return int.Parse(userIdClaim);
    }

    [HttpPost]
    public async Task<ActionResult<TripResponseDto>> CreateTrip(CreateTripDto createTripDto)
    {
        try
        {
            var userId = GetUserId();
            var trip = await _tripService.CreateTripAsync(userId, createTripDto);
            return Ok(trip);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<TripResponseDto>> UpdateTrip(int id, UpdateTripDto updateTripDto)
    {
        try
        {
            var userId = GetUserId();
            var trip = await _tripService.UpdateTripAsync(id, userId, updateTripDto);
            return Ok(trip);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<TripResponseDto>> GetTrip(int id)
    {
        try
        {
            var userId = GetUserId();
            var trip = await _tripService.GetTripByIdAsync(id, userId);
            return Ok(trip);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpGet]
    public async Task<ActionResult<List<TripResponseDto>>> GetUserTrips()
    {
        try
        {
            var userId = GetUserId();
            var trips = await _tripService.GetUserTripsAsync(userId);
            return Ok(trips);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteTrip(int id)
    {
        try
        {
            var userId = GetUserId();
            await _tripService.DeleteTripAsync(id, userId);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("{id}/share")]
    public async Task<ActionResult<TripResponseDto>> ShareTrip(int id)
    {
        try
        {
            var userId = GetUserId();
            var trip = await _tripService.ShareTripAsync(id, userId);
            return Ok(trip);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("join/{shareCode}")]
    public async Task<ActionResult<TripResponseDto>> JoinTrip(string shareCode)
    {
        try
        {
            var userId = GetUserId();
            var trip = await _tripService.JoinTripByCodeAsync(shareCode, userId);
            return Ok(trip);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
