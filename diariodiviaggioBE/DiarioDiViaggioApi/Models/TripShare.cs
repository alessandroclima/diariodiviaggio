using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DiarioDiViaggioApi.Models;

public class TripShare
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int TripId { get; set; }

    [ForeignKey(nameof(TripId))]
    public Trip Trip { get; set; } = null!;

    [Required]
    public int UserId { get; set; }

    [ForeignKey(nameof(UserId))]
    public User User { get; set; } = null!;

    public DateTime SharedDate { get; set; } = DateTime.UtcNow;
}
