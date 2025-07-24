using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Services;

namespace DiarioDiViaggioApi.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class TripItemController : ControllerBase
{
    private readonly ITripItemService _tripItemService;

    public TripItemController(ITripItemService tripItemService)
    {
        _tripItemService = tripItemService;
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

    [HttpPost("trip/{tripId}")]
    public async Task<ActionResult<TripItemResponseDto>> CreateTripItem(int tripId, [FromForm] CreateTripItemDto createTripItemDto)
    {
        try
        {
            var userId = GetUserId();
            var tripItem = await _tripItemService.CreateTripItemAsync(tripId, userId, createTripItemDto);
            return Ok(tripItem);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<TripItemResponseDto>> UpdateTripItem(int id, [FromForm] UpdateTripItemDto updateTripItemDto)
    {
        try
        {
            var userId = GetUserId();
            var tripItem = await _tripItemService.UpdateTripItemAsync(id, userId, updateTripItemDto);
            return Ok(tripItem);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<TripItemResponseDto>> GetTripItem(int id)
    {
        try
        {
            var userId = GetUserId();
            var tripItem = await _tripItemService.GetTripItemByIdAsync(id, userId);
            return Ok(tripItem);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpGet("trip/{tripId}")]
    public async Task<ActionResult<List<TripItemResponseDto>>> GetTripItems(int tripId)
    {
        try
        {
            var userId = GetUserId();
            var tripItems = await _tripItemService.GetTripItemsAsync(tripId, userId);
            return Ok(tripItems);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteTripItem(int id)
    {
        try
        {
            var userId = GetUserId();
            await _tripItemService.DeleteTripItemAsync(id, userId);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
