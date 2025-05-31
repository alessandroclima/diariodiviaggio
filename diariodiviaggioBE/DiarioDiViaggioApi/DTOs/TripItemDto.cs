namespace DiarioDiViaggioApi.DTOs;

public class CreateTripItemDto
{
    public required string Title { get; set; }
    public string? Description { get; set; }
    public required string Type { get; set; } // "Photo", "Note", "Restaurant", "Hotel", "Attraction"
    public string? Location { get; set; }
    public int? Rating { get; set; }
    public IFormFile? Image { get; set; }
}

public class UpdateTripItemDto
{
    public required string Title { get; set; }
    public string? Description { get; set; }
    public string? Location { get; set; }
    public int? Rating { get; set; }
}

public class TripItemResponseDto
{
    public required int Id { get; set; }
    public required string Title { get; set; }
    public string? Description { get; set; }
    public required string Type { get; set; }
    public string? Location { get; set; }
    public int? Rating { get; set; }
    public string? ImageUrl { get; set; }
    public required DateTime CreatedAt { get; set; }
    public required string CreatedByUsername { get; set; }
}
