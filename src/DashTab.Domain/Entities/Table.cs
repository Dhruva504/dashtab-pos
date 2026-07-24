using DashTab.Domain.Common;
using DashTab.Domain.Enums;

namespace DashTab.Domain.Entities;

public class Table : BaseEntity
{
    public Guid FloorId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int Capacity { get; set; }
    public TableStatus Status { get; set; } = TableStatus.Available;
    
    // Spatial properties for rendering floor plan
    public double X { get; set; }
    public double Y { get; set; }
    public double Width { get; set; }
    public double Height { get; set; }
    public TableShape Shape { get; set; } = TableShape.Rectangle;

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public Floor Floor { get; set; } = null!;
    public ICollection<Order> Orders { get; set; } = new List<Order>();
}
