using DiarioDiViaggioApi.DTOs;

namespace DiarioDiViaggioApi.Services;

public interface IAuthService
{
    Task<AuthResponseDto> RegisterAsync(RegisterDto registerDto);
    Task<AuthResponseDto> LoginAsync(LoginDto loginDto);
    Task<string> GenerateJwtToken(Models.User user);
}
