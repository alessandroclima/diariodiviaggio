using System.ComponentModel.DataAnnotations;

namespace DiarioDiViaggioApi.Models;

public class PasswordResetToken
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string Token { get; set; } = string.Empty;

    [Required]
    public int UserId { get; set; }

    [Required]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Required]
    public DateTime ExpiryDate { get; set; } = DateTime.UtcNow.AddHours(1); // 1 hour expiry

    public bool IsUsed { get; set; } = false;

    public DateTime? UsedAt { get; set; }

    public string? IpAddress { get; set; }

    // Navigation property
    public User User { get; set; } = null!;
}
