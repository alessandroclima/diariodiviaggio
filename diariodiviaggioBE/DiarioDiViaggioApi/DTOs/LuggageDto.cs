namespace DiarioDiViaggioApi.DTOs;

public class CreateLuggageDto
{
    public required string Name { get; set; }
    public string? Description { get; set; }
}

public class UpdateLuggageDto
{
    public required string Name { get; set; }
    public string? Description { get; set; }
}

public class LuggageResponseDto
{
    public required int Id { get; set; }
    public required string Name { get; set; }
    public string? Description { get; set; }
    public List<LuggageItemResponseDto> Items { get; set; } = new();
}

public class CreateLuggageItemDto
{
    public required string Name { get; set; }
    public string? Notes { get; set; }
    public int Quantity { get; set; } = 1;
}

public class UpdateLuggageItemDto
{
    public required string Name { get; set; }
    public string? Notes { get; set; }
    public int Quantity { get; set; }
    public bool IsPacked { get; set; }
}

public class LuggageItemResponseDto
{
    public required int Id { get; set; }
    public required string Name { get; set; }
    public string? Notes { get; set; }
    public int Quantity { get; set; }
    public bool IsPacked { get; set; }
}
