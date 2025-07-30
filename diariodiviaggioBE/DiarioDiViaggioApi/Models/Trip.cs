using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DiarioDiViaggioApi.Models;

public class Trip
{
    [Key]
    public int Id { get; set; }

    [Required]
    [StringLength(100)]
    public string Title { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    [Required]
    public DateTime StartDate { get; set; } =  DateTime.UtcNow;


    public DateTime? EndDate { get; set; }  = DateTime.UtcNow;

    [Required]
    public int OwnerId { get; set; }

    [ForeignKey(nameof(OwnerId))]
    public User Owner { get; set; } = null!;

    public string ShareCode { get; set; } = string.Empty;

    public byte[]? TripImage { get; set; }

    public List<TripShare> SharedWithUsers { get; set; } = new();
    public List<TripItem> Items { get; set; } = new();
    public List<Luggage> Luggages { get; set; } = new();
    public List<Itinerary> Itineraries { get; set; } = new();
}
