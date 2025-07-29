using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using DiarioDiViaggioApi.Data;
using DiarioDiViaggioApi.DTOs;
using DiarioDiViaggioApi.Models;
using System.Security.Cryptography;

namespace DiarioDiViaggioApi.Services;

public class AuthService : IAuthService
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly IEmailService _emailService;

    public AuthService(ApplicationDbContext context, IConfiguration configuration, IEmailService emailService)
    {
        _context = context;
        _configuration = configuration;
        _emailService = emailService;
    }

    public async Task<(AuthResponseDto response, string refreshToken)> RegisterAsync(RegisterDto registerDto)
    {
        // Check if user already exists
        if (await _context.Users.AnyAsync(u => u.Email == registerDto.Email))
        {
            throw new InvalidOperationException("Email already registered");
        }

        if (await _context.Users.AnyAsync(u => u.Username == registerDto.Username))
        {
            throw new InvalidOperationException("Username already taken");
        }

        // Create new user
        var user = new User
        {
            Username = registerDto.Username,
            Email = registerDto.Email,
            PasswordHash = HashPassword(registerDto.Password)
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        // Generate JWT token and refresh token
        var token = await GenerateJwtToken(user);
        var refreshTokenEntity = await GenerateRefreshTokenAsync(user);

        var response = new AuthResponseDto
        {
            Token = token,
            Username = user.Username,
            Email = user.Email,
            ProfileImageBase64 = user.ProfileImage != null ? Convert.ToBase64String(user.ProfileImage) : null
        };

        return (response, refreshTokenEntity.Token);
    }

    public async Task<(AuthResponseDto response, string refreshToken)> LoginAsync(LoginDto loginDto)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Email == loginDto.Email);

        if (user == null || !VerifyPassword(loginDto.Password, user.PasswordHash))
        {
            throw new InvalidOperationException("Invalid email or password");
        }

        var token = await GenerateJwtToken(user);
        var refreshTokenEntity = await GenerateRefreshTokenAsync(user);

        var response = new AuthResponseDto
        {
            Token = token,
            Username = user.Username,
            Email = user.Email,
            ProfileImageBase64 = user.ProfileImage != null ? Convert.ToBase64String(user.ProfileImage) : null
        };

        return (response, refreshTokenEntity.Token);
    }

    public async Task<(string accessToken, string refreshToken)> RefreshTokenAsync(RefreshTokenDto refreshTokenDto)
    {
        var refreshToken = await _context.RefreshTokens
            .Include(rt => rt.User)
            .FirstOrDefaultAsync(rt => rt.Token == refreshTokenDto.RefreshToken);

        if (refreshToken == null || !refreshToken.IsActive)
        {
            throw new InvalidOperationException("Invalid or expired refresh token");
        }

        // Revoke the old refresh token
        refreshToken.IsRevoked = true;
        refreshToken.RevokedAt = DateTime.UtcNow;

        // Generate new tokens
        var newAccessToken = await GenerateJwtToken(refreshToken.User);
        var newRefreshTokenEntity = await GenerateRefreshTokenAsync(refreshToken.User);

        await _context.SaveChangesAsync();

        return (newAccessToken, newRefreshTokenEntity.Token);
    }

    public async Task RevokeRefreshTokenAsync(string refreshToken)
    {
        var token = await _context.RefreshTokens
            .FirstOrDefaultAsync(rt => rt.Token == refreshToken);

        if (token != null && token.IsActive)
        {
            token.IsRevoked = true;
            token.RevokedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
    }

    public async Task<RefreshToken> GenerateRefreshTokenAsync(User user)
    {
        var refreshToken = new RefreshToken
        {
            Token = GenerateSecureToken(),
            ExpiryDate = DateTime.UtcNow.AddDays(7), // Refresh tokens last 7 days
            UserId = user.Id,
            CreatedAt = DateTime.UtcNow
        };

        _context.RefreshTokens.Add(refreshToken);
        await _context.SaveChangesAsync();

        return refreshToken;
    }

    private static string GenerateSecureToken()
    {
        using var rng = RandomNumberGenerator.Create();
        var tokenBytes = new byte[64];
        rng.GetBytes(tokenBytes);
        return Convert.ToBase64String(tokenBytes);
    }

    public async Task<string> GenerateJwtToken(User user)
    {
        var jwtSettings = _configuration.GetSection("JwtSettings");
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings["SecretKey"]!));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, user.Email),
            new Claim(JwtRegisteredClaimNames.UniqueName, user.Username),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = new JwtSecurityToken(
            issuer: jwtSettings["Issuer"],
            audience: jwtSettings["Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(Convert.ToDouble(jwtSettings["ExpirationMinutes"])),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static string HashPassword(string password)
    {
        using var sha256 = SHA256.Create();
        var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
        return Convert.ToBase64String(hashedBytes);
    }

    private static bool VerifyPassword(string password, string hash)
    {
        return HashPassword(password) == hash;
    }

    public async Task RequestPasswordResetAsync(PasswordResetRequestDto request, string ipAddress)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
        if (user == null)
        {
            // Don't reveal if email exists or not for security
            return;
        }

        // Invalidate any existing unused password reset tokens for this user
        var existingTokens = await _context.PasswordResetTokens
            .Where(prt => prt.UserId == user.Id && !prt.IsUsed && prt.ExpiryDate > DateTime.UtcNow)
            .ToListAsync();

        foreach (var token in existingTokens)
        {
            token.IsUsed = true;
            token.UsedAt = DateTime.UtcNow;
        }

        // Generate new reset token
        var resetToken = GenerateSecureToken();
        var passwordResetToken = new PasswordResetToken
        {
            Token = resetToken,
            UserId = user.Id,
            CreatedAt = DateTime.UtcNow,
            ExpiryDate = DateTime.UtcNow.AddHours(1), // 1 hour expiry
            IpAddress = ipAddress
        };

        _context.PasswordResetTokens.Add(passwordResetToken);
        await _context.SaveChangesAsync();

        // Send reset email
        await _emailService.SendPasswordResetEmailAsync(user.Email, user.Username, resetToken);
    }

    public async Task ResetPasswordAsync(PasswordResetDto resetDto, string ipAddress)
    {
        var passwordResetToken = await _context.PasswordResetTokens
            .Include(prt => prt.User)
            .FirstOrDefaultAsync(prt => prt.Token == resetDto.Token);

        if (passwordResetToken == null)
        {
            throw new InvalidOperationException("Invalid reset token");
        }

        if (passwordResetToken.IsUsed)
        {
            throw new InvalidOperationException("Reset token has already been used");
        }

        if (passwordResetToken.ExpiryDate < DateTime.UtcNow)
        {
            throw new InvalidOperationException("Reset token has expired");
        }

        // Validate new password (basic validation)
        if (string.IsNullOrEmpty(resetDto.NewPassword) || resetDto.NewPassword.Length < 6)
        {
            throw new InvalidOperationException("Password must be at least 6 characters long");
        }

        // Update user password
        var user = passwordResetToken.User;
        user.PasswordHash = HashPassword(resetDto.NewPassword);

        // Mark token as used
        passwordResetToken.IsUsed = true;
        passwordResetToken.UsedAt = DateTime.UtcNow;

        // Revoke all existing refresh tokens for security
        var userRefreshTokens = await _context.RefreshTokens
            .Where(rt => rt.UserId == user.Id && rt.IsRevoked == false && DateTime.UtcNow < rt.ExpiryDate)
            .ToListAsync();

        foreach (var refreshToken in userRefreshTokens)
        {
            refreshToken.IsRevoked = true;
            refreshToken.RevokedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
    }
}
