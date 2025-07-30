using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace DiarioDiViaggioApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ItineraryController : ControllerBase
    {
        private readonly IItineraryService _itineraryService;

        public ItineraryController(IItineraryService itineraryService)
        {
            _itineraryService = itineraryService;
        }

        private int GetUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out int userId))
            {
                throw new UnauthorizedAccessException("Invalid user token");
            }
            return userId;
        }

        [HttpPost]
        public async Task<ActionResult<ItineraryDto>> CreateItinerary([FromBody] CreateItineraryDto createItineraryDto)
        {
            try
            {
                var userId = GetUserId();
                var itinerary = await _itineraryService.CreateItineraryAsync(createItineraryDto, userId);
                return Ok(itinerary);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Forbid(ex.Message);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<ItineraryDto>> GetItinerary(int id)
        {
            try
            {
                var userId = GetUserId();
                var itinerary = await _itineraryService.GetItineraryByIdAsync(id, userId);
                
                if (itinerary == null)
                {
                    return NotFound("Itinerary not found");
                }

                return Ok(itinerary);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Forbid(ex.Message);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        [HttpGet("trip/{tripId}")]
        public async Task<ActionResult<List<ItineraryDto>>> GetItinerariesByTrip(int tripId)
        {
            try
            {
                var userId = GetUserId();
                var itineraries = await _itineraryService.GetItinerariesByTripAsync(tripId, userId);
                return Ok(itineraries);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Forbid(ex.Message);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        [HttpGet("trip/{tripId}/calendar")]
        public async Task<ActionResult<TripItineraryCalendarDto>> GetTripItineraryCalendar(int tripId)
        {
            try
            {
                var userId = GetUserId();
                var calendar = await _itineraryService.GetTripItineraryCalendarAsync(tripId, userId);
                
                if (calendar == null)
                {
                    return NotFound("Trip not found or access denied");
                }

                return Ok(calendar);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Forbid(ex.Message);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        [HttpGet("trip/{tripId}/date/{date}")]
        public async Task<ActionResult<List<ItineraryDto>>> GetItinerariesByDate(int tripId, DateTime date)
        {
            try
            {
                var userId = GetUserId();
                var itineraries = await _itineraryService.GetItinerariesByDateAsync(tripId, date, userId);
                return Ok(itineraries);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Forbid(ex.Message);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        [HttpPut("{id}")]
        public async Task<ActionResult<ItineraryDto>> UpdateItinerary(int id, [FromBody] UpdateItineraryDto updateItineraryDto)
        {
            try
            {
                var userId = GetUserId();
                var itinerary = await _itineraryService.UpdateItineraryAsync(id, updateItineraryDto, userId);
                
                if (itinerary == null)
                {
                    return NotFound("Itinerary not found or access denied");
                }

                return Ok(itinerary);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Forbid(ex.Message);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        [HttpDelete("{id}")]
        public async Task<ActionResult> DeleteItinerary(int id)
        {
            try
            {
                var userId = GetUserId();
                var success = await _itineraryService.DeleteItineraryAsync(id, userId);
                
                if (!success)
                {
                    return NotFound("Itinerary not found or access denied");
                }

                return NoContent();
            }
            catch (UnauthorizedAccessException ex)
            {
                return Forbid(ex.Message);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }
    }
}
