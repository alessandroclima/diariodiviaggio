using System.ComponentModel.DataAnnotations;

namespace DiarioDiViaggioApi.Models;

public class User
{
    [Key]
    public int Id { get; set; }

    [Required]
    [StringLength(100)]
    public string Username { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string PasswordHash { get; set; } = string.Empty;

    public List<Trip> Trips { get; set; } = new();
    public List<TripShare> SharedTrips { get; set; } = new();
}
