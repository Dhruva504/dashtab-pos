using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class Modifier : BaseEntity
{
    public Guid ModifierGroupId { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal PriceAdjustment { get; set; } = 0;
    public bool IsActive { get; set; } = true;
    public int SortOrder { get; set; } = 0;

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public ModifierGroup ModifierGroup { get; set; } = null!;
}
