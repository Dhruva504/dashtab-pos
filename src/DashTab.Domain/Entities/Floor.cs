using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class Floor : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string BackgroundColor { get; set; } = "#FFFFFF";
    public string? BackgroundImageUrl { get; set; }
    public bool IsActive { get; set; } = true;

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public ICollection<Table> Tables { get; set; } = new List<Table>();
}
