using Microsoft.AspNetCore.Mvc;
using DiarioDiViaggioApi.Services;
using DiarioDiViaggioApi.DTOs;

namespace DiarioDiViaggioApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(IAuthService authService, ILogger<AuthController> logger)
    {
        _authService = authService;
        _logger = logger;
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
    public async Task<ActionResult<RefreshTokenResponseDto>> RefreshToken([FromBody] RefreshTokenDto? refreshTokenDto)
    {
        try
        {
            // Add debugging information
            var isDevelopment = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>().IsDevelopment();
            if (isDevelopment)
            {
                Console.WriteLine("=== Refresh Token Request Debug ===");
                Console.WriteLine($"Request Origin: {Request.Headers["Origin"]}");
                Console.WriteLine($"Request Host: {Request.Host}");
                Console.WriteLine($"Available Cookies: {string.Join(", ", Request.Cookies.Keys)}");
                Console.WriteLine($"User-Agent: {Request.Headers["User-Agent"]}");
            }
            
            // Prefer HttpOnly cookie, fallback to request body for clients that cannot use cookies reliably.
            var refreshToken = Request.Cookies["refreshToken"];
            if (string.IsNullOrWhiteSpace(refreshToken))
            {
                refreshToken = refreshTokenDto?.RefreshToken;
            }

            if (string.IsNullOrEmpty(refreshToken))
            {
                if (isDevelopment)
                {
                    Console.WriteLine("ERROR: Refresh token cookie not found or empty");
                    Console.WriteLine($"All cookies received: {string.Join("; ", Request.Cookies.Select(c => $"{c.Key}={c.Value}"))}");
                }
                return BadRequest(new { message = "Refresh token not found" });
            }

            if (isDevelopment)
            {
                Console.WriteLine($"Found refresh token cookie: {refreshToken[..Math.Min(10, refreshToken.Length)]}...");
            }

            var (accessToken, newRefreshToken) = await _authService.RefreshTokenAsync(refreshToken);
            
            // Set new refresh token as HttpOnly cookie
            SetRefreshTokenCookie(newRefreshToken);
            
            if (isDevelopment)
            {
                Console.WriteLine("Successfully refreshed token and set new cookie");
            }
            
            return Ok(new RefreshTokenResponseDto
            {
                Token = accessToken,
                RefreshToken = newRefreshToken
            });
        }
        catch (InvalidOperationException ex)
        {
            // Clear the invalid refresh token cookie
            ClearRefreshTokenCookie();
            Console.WriteLine($"Refresh token error: {ex.Message}");
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("revoke")]
    public async Task<ActionResult> RevokeToken([FromBody] RefreshTokenDto? refreshTokenDto)
    {
        try
        {
            // Prefer HttpOnly cookie, fallback to request body for clients that cannot use cookies reliably.
            var refreshToken = Request.Cookies["refreshToken"];
            if (string.IsNullOrWhiteSpace(refreshToken))
            {
                refreshToken = refreshTokenDto?.RefreshToken;
            }

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
        var isDevelopment = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>().IsDevelopment();
        
        var cookieOptions = new CookieOptions
        {
            HttpOnly = true,
            Secure = !isDevelopment, // Only require HTTPS in production
            SameSite = SameSiteMode.None, // Allow cross-origin requests
            Expires = DateTimeOffset.UtcNow.AddDays(7), // 7 days expiration
            Path = "/"
        };

        Response.Cookies.Append("refreshToken", refreshToken, cookieOptions);
        
        // Add debugging in development
        if (isDevelopment)
        {
            Console.WriteLine($"Setting refresh token cookie with options: HttpOnly={cookieOptions.HttpOnly}, Secure={cookieOptions.Secure}, SameSite={cookieOptions.SameSite}");
        }
    }

    private void ClearRefreshTokenCookie()
    {
        var isDevelopment = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>().IsDevelopment();
        
        var cookieOptions = new CookieOptions
        {
            HttpOnly = true,
            Secure = !isDevelopment, // Only require HTTPS in production
            SameSite = SameSiteMode.None, // Allow cross-origin requests
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
            _logger.LogError(ex, "Unexpected error in forgot-password for email {Email}", request.Email);
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
            _logger.LogError(ex, "Unexpected error in reset-password");
            return StatusCode(500, new { message = "An error occurred while resetting your password." });
        }
    }

    [HttpGet("test-cookie")]
    public ActionResult TestCookie()
    {
        var cookie = Request.Cookies["refreshToken"];
        return Ok(new { 
            cookieExists = !string.IsNullOrEmpty(cookie),
            cookieValue = cookie?.Length > 10 ? cookie.Substring(0, 10) + "..." : cookie,
            allCookies = Request.Cookies.Keys.ToList(),
            origin = Request.Headers["Origin"].ToString(),
            userAgent = Request.Headers["User-Agent"].ToString(),
            requestHeaders = Request.Headers.ToDictionary(h => h.Key, h => h.Value.ToString())
        });
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
