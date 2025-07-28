using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DiarioDiViaggioApi.Data;
using DiarioDiViaggioApi.DTOs;
using System.Security.Claims;

namespace DiarioDiViaggioApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProfileController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public ProfileController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<UserProfileDto>> GetProfile()
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
        {
            return NotFound("User not found");
        }

        var profileDto = new UserProfileDto
        {
            Id = user.Id,
            Username = user.Username,
            Email = user.Email,
            ProfileImageBase64 = user.ProfileImage != null ? Convert.ToBase64String(user.ProfileImage) : null
        };

        return Ok(profileDto);
    }

    [HttpPut]
    public async Task<ActionResult<UserProfileDto>> UpdateProfile([FromBody] UpdateUserProfileRequest request)
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
        {
            return NotFound("User not found");
        }

        // Check if username is already taken by another user
        if (request.Username != user.Username)
        {
            var existingUser = await _context.Users
                .FirstOrDefaultAsync(u => u.Username == request.Username && u.Id != userId);
            if (existingUser != null)
            {
                return BadRequest("Username is already taken");
            }
            user.Username = request.Username;
        }

        // Update profile image
        if (request.ProfileImageBase64 != null)
        {
            try
            {
                user.ProfileImage = Convert.FromBase64String(request.ProfileImageBase64);
            }
            catch (FormatException)
            {
                return BadRequest("Invalid image format");
            }
        }

        await _context.SaveChangesAsync();

        var updatedProfileDto = new UserProfileDto
        {
            Id = user.Id,
            Username = user.Username,
            Email = user.Email,
            ProfileImageBase64 = user.ProfileImage != null ? Convert.ToBase64String(user.ProfileImage) : null
        };

        return Ok(updatedProfileDto);
    }

    [HttpDelete("profile-image")]
    public async Task<ActionResult> DeleteProfileImage()
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
        {
            return NotFound("User not found");
        }

        user.ProfileImage = null;
        await _context.SaveChangesAsync();

        return Ok("Profile image deleted successfully");
    }
}
