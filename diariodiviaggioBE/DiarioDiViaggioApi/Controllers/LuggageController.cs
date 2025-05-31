using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Services;

namespace DiarioDiViaggioApi.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class LuggageController : ControllerBase
{
    private readonly ILuggageService _luggageService;

    public LuggageController(ILuggageService luggageService)
    {
        _luggageService = luggageService;
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
    public async Task<ActionResult<LuggageResponseDto>> CreateLuggage(int tripId, CreateLuggageDto createLuggageDto)
    {
        try
        {
            var userId = GetUserId();
            var luggage = await _luggageService.CreateLuggageAsync(tripId, userId, createLuggageDto);
            return Ok(luggage);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<LuggageResponseDto>> UpdateLuggage(int id, UpdateLuggageDto updateLuggageDto)
    {
        try
        {
            var userId = GetUserId();
            var luggage = await _luggageService.UpdateLuggageAsync(id, userId, updateLuggageDto);
            return Ok(luggage);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<LuggageResponseDto>> GetLuggage(int id)
    {
        try
        {
            var userId = GetUserId();
            var luggage = await _luggageService.GetLuggageByIdAsync(id, userId);
            return Ok(luggage);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpGet("trip/{tripId}")]
    public async Task<ActionResult<List<LuggageResponseDto>>> GetTripLuggages(int tripId)
    {
        try
        {
            var userId = GetUserId();
            var luggages = await _luggageService.GetTripLuggagesAsync(tripId, userId);
            return Ok(luggages);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteLuggage(int id)
    {
        try
        {
            var userId = GetUserId();
            await _luggageService.DeleteLuggageAsync(id, userId);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("{luggageId}/items")]
    public async Task<ActionResult<LuggageItemResponseDto>> AddLuggageItem(int luggageId, CreateLuggageItemDto createItemDto)
    {
        try
        {
            var userId = GetUserId();
            var item = await _luggageService.AddLuggageItemAsync(luggageId, userId, createItemDto);
            return Ok(item);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("items/{id}")]
    public async Task<ActionResult<LuggageItemResponseDto>> UpdateLuggageItem(int id, UpdateLuggageItemDto updateItemDto)
    {
        try
        {
            var userId = GetUserId();
            var item = await _luggageService.UpdateLuggageItemAsync(id, userId, updateItemDto);
            return Ok(item);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("items/{id}")]
    public async Task<ActionResult<LuggageItemResponseDto>> GetLuggageItem(int id)
    {
        try
        {
            var userId = GetUserId();
            var item = await _luggageService.GetLuggageItemByIdAsync(id, userId);
            return Ok(item);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpDelete("items/{id}")]
    public async Task<ActionResult> DeleteLuggageItem(int id)
    {
        try
        {
            var userId = GetUserId();
            await _luggageService.DeleteLuggageItemAsync(id, userId);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
