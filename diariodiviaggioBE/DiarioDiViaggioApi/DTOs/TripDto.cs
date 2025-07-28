namespace DiarioDiViaggioApi.DTOs;

public class CreateTripDto
{
    public required string Title { get; set; }
    public string? Description { get; set; }
    public required DateTime StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? TripImageBase64 { get; set; }
}

public class UpdateTripDto
{
    public required string Title { get; set; }
    public string? Description { get; set; }
    public required DateTime StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? TripImageBase64 { get; set; }
}

public class TripResponseDto
{
    public required int Id { get; set; }
    public required string Title { get; set; }
    public string? Description { get; set; }
    public required DateTime StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public required string ShareCode { get; set; }
    public required string OwnerUsername { get; set; }
    public List<string> SharedWithUsernames { get; set; } = new();
    public string? TripImageBase64 { get; set; }
}
