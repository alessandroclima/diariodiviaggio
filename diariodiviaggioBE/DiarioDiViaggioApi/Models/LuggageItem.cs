using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DiarioDiViaggioApi.Models;

public class LuggageItem
{
    [Key]
    public int Id { get; set; }

    [Required]
    [StringLength(100)]
    public string Name { get; set; } = string.Empty;

    public string? Notes { get; set; }

    public int Quantity { get; set; } = 1;

    public bool IsPacked { get; set; }

    [Required]
    public int LuggageId { get; set; }

    [ForeignKey(nameof(LuggageId))]
    public Luggage Luggage { get; set; } = null!;
}
