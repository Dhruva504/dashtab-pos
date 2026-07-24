using DashTab.Domain.Enums;

namespace DashTab.Application.Features.Menu.DTOs;

public class ProductDto
{
    public Guid Id { get; set; }
    public Guid CategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? ShortName { get; set; }
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public string? ImageUrl { get; set; }
    public string? Color { get; set; }
    public bool IsAvailable { get; set; }
    public int SortOrder { get; set; }
    public int? PrepTimeMinutes { get; set; }
}
