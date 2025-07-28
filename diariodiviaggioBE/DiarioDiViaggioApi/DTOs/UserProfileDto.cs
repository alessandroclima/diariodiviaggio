namespace DiarioDiViaggioApi.DTOs;

public class UserProfileDto
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? ProfileImageBase64 { get; set; }
}

public class UpdateUserProfileRequest
{
    public string Username { get; set; } = string.Empty;
    public string? ProfileImageBase64 { get; set; }
}
