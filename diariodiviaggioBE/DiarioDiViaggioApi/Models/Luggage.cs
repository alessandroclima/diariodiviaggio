using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DiarioDiViaggioApi.Models;

public class Luggage
{
    [Key]
    public int Id { get; set; }

    [Required]
    [StringLength(100)]
    public string Name { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    [Required]
    public int TripId { get; set; }

    [ForeignKey(nameof(TripId))]
    public Trip Trip { get; set; } = null!;

    public List<LuggageItem> Items { get; set; } = new();
}
