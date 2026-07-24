using DashTab.Domain.Enums;

namespace DashTab.Application.Features.Floors.DTOs;

public class TableDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int Capacity { get; set; }
    public TableStatus Status { get; set; }
    public double X { get; set; }
    public double Y { get; set; }
    public double Width { get; set; }
    public double Height { get; set; }
    public TableShape Shape { get; set; }
}
