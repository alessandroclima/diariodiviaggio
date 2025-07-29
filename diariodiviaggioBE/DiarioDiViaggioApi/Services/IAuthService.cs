using DiarioDiViaggioApi.DTOs;

namespace DiarioDiViaggioApi.Services;

public interface IAuthService
{
    Task<(AuthResponseDto response, string refreshToken)> RegisterAsync(RegisterDto registerDto);
    Task<(AuthResponseDto response, string refreshToken)> LoginAsync(LoginDto loginDto);
    Task<(string accessToken, string refreshToken)> RefreshTokenAsync(RefreshTokenDto refreshTokenDto);
    Task RevokeRefreshTokenAsync(string refreshToken);
    Task<string> GenerateJwtToken(Models.User user);
    Task RequestPasswordResetAsync(PasswordResetRequestDto request, string ipAddress);
    Task ResetPasswordAsync(PasswordResetDto resetDto, string ipAddress);
}
