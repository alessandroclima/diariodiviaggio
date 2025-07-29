using Microsoft.AspNetCore.Mvc;
using DiarioDiViaggioApi.Services;
using DiarioDiViaggioApi.DTOs;

namespace DiarioDiViaggioApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    public async Task<ActionResult<AuthResponseDto>> Register(RegisterDto registerDto)
    {
        try
        {
            var (response, refreshToken) = await _authService.RegisterAsync(registerDto);
            
            // Set refresh token as HttpOnly cookie
            SetRefreshTokenCookie(refreshToken);
            
            // Return only the JWT token (not refresh token)
            return Ok(response);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponseDto>> Login(LoginDto loginDto)
    {
        try
        {
            var (response, refreshToken) = await _authService.LoginAsync(loginDto);
            
            // Set refresh token as HttpOnly cookie
            SetRefreshTokenCookie(refreshToken);
            
            // Return only the JWT token (not refresh token)
            return Ok(response);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("refresh")]
    public async Task<ActionResult> RefreshToken()
    {
        try
        {
            // Get refresh token from HttpOnly cookie
            var refreshToken = Request.Cookies["refreshToken"];
            if (string.IsNullOrEmpty(refreshToken))
            {
                return BadRequest(new { message = "Refresh token not found" });
            }

            var refreshTokenDto = new RefreshTokenDto { RefreshToken = refreshToken };
            var (accessToken, newRefreshToken) = await _authService.RefreshTokenAsync(refreshTokenDto);
            
            // Set new refresh token as HttpOnly cookie
            SetRefreshTokenCookie(newRefreshToken);
            
            // Return only the new access token
            return Ok(new { Token = accessToken });
        }
        catch (InvalidOperationException ex)
        {
            // Clear the invalid refresh token cookie
            ClearRefreshTokenCookie();
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("revoke")]
    public async Task<ActionResult> RevokeToken()
    {
        try
        {
            // Get refresh token from HttpOnly cookie
            var refreshToken = Request.Cookies["refreshToken"];
            if (string.IsNullOrEmpty(refreshToken))
            {
                return BadRequest(new { message = "Refresh token not found" });
            }

            await _authService.RevokeRefreshTokenAsync(refreshToken);
            
            // Clear the refresh token cookie
            ClearRefreshTokenCookie();
            
            return Ok(new { message = "Token revoked successfully" });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    private void SetRefreshTokenCookie(string refreshToken)
    {
        var cookieOptions = new CookieOptions
        {
            HttpOnly = true,
            Secure = Request.IsHttps, // Only secure over HTTPS, allow HTTP in development
            SameSite = SameSiteMode.Strict,
            Expires = DateTimeOffset.UtcNow.AddDays(7), // 7 days expiration
            Path = "/"
        };

        Response.Cookies.Append("refreshToken", refreshToken, cookieOptions);
    }

    private void ClearRefreshTokenCookie()
    {
        var cookieOptions = new CookieOptions
        {
            HttpOnly = true,
            Secure = Request.IsHttps,
            SameSite = SameSiteMode.Strict,
            Expires = DateTimeOffset.UtcNow.AddDays(-1), // Expire immediately
            Path = "/"
        };

        Response.Cookies.Append("refreshToken", "", cookieOptions);
    }

    [HttpPost("forgot-password")]
    public async Task<ActionResult> ForgotPassword(PasswordResetRequestDto request)
    {
        try
        {
            var ipAddress = GetClientIpAddress();
            await _authService.RequestPasswordResetAsync(request, ipAddress);
            
            // Always return success to prevent email enumeration attacks
            return Ok(new { message = "If the email address is registered, you will receive a password reset link shortly." });
        }
        catch (Exception ex)
        {
            // Log the exception but don't expose details to client
            return StatusCode(500, new { message = "An error occurred while processing your request." });
        }
    }

    [HttpPost("reset-password")]
    public async Task<ActionResult> ResetPassword(PasswordResetDto resetDto)
    {
        try
        {
            var ipAddress = GetClientIpAddress();
            await _authService.ResetPasswordAsync(resetDto, ipAddress);
            
            return Ok(new { message = "Password has been reset successfully. You can now log in with your new password." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            // Log the exception but don't expose details to client
            return StatusCode(500, new { message = "An error occurred while resetting your password." });
        }
    }

    private string GetClientIpAddress()
    {
        // Try to get the real IP address from various headers
        var ipAddress = Request.Headers["X-Forwarded-For"].FirstOrDefault()?.Split(',').FirstOrDefault()?.Trim();
        
        if (string.IsNullOrEmpty(ipAddress))
        {
            ipAddress = Request.Headers["X-Real-IP"].FirstOrDefault();
        }
        
        if (string.IsNullOrEmpty(ipAddress))
        {
            ipAddress = Request.HttpContext.Connection.RemoteIpAddress?.ToString();
        }
        
        return ipAddress ?? "Unknown";
    }
}
