namespace DiarioDiViaggioApi.DTOs;

public class RegisterDto
{
    public required string Username { get; set; }
    public required string Email { get; set; }
    public required string Password { get; set; }
}

public class LoginDto
{
    public required string Email { get; set; }
    public required string Password { get; set; }
}

public class AuthResponseDto
{
    public required string Token { get; set; }
    public required string Username { get; set; }
    public required string Email { get; set; }
    public string? ProfileImageBase64 { get; set; }
}

public class RefreshTokenDto
{
    public required string RefreshToken { get; set; }
}

public class RefreshTokenResponseDto
{
    public required string Token { get; set; }
    public required string RefreshToken { get; set; }
}
