namespace DashTab.Application.Features.Floors.DTOs;

public class FloorDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string BackgroundColor { get; set; } = string.Empty;
    public string? BackgroundImageUrl { get; set; }
    public List<TableDto> Tables { get; set; } = new();
}
