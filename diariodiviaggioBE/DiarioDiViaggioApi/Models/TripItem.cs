using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DiarioDiViaggioApi.Models;

public enum ItemType
{
    Photo,
    Note,
    Restaurant,
    Hotel,
    Attraction
}

public class TripItem
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int TripId { get; set; }

    [ForeignKey(nameof(TripId))]
    public Trip Trip { get; set; } = null!;

    [Required]
    public ItemType Type { get; set; }

    [Required]
    [StringLength(200)]
    public string Title { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    public byte[]? ImageData { get; set; }

    public string? Location { get; set; }

    [Range(1, 5)]
    public int? Rating { get; set; }

    [Required]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Required]
    public int CreatedById { get; set; }

    [ForeignKey(nameof(CreatedById))]
    public User CreatedBy { get; set; } = null!;
}
