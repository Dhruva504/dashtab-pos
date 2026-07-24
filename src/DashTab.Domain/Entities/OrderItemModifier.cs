using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class OrderItemModifier : BaseEntity
{
    public Guid OrderItemId { get; set; }
    public Guid ModifierId { get; set; }
    
    public string ModifierName { get; set; } = string.Empty; // Snapshot
    public decimal PriceAdjustment { get; set; } // Snapshot

    // Navigation properties
    public OrderItem OrderItem { get; set; } = null!;
    public Modifier Modifier { get; set; } = null!;
}
