using DashTab.Domain.Common;
using DashTab.Domain.Enums;

namespace DashTab.Domain.Entities;

public class OrderItem : BaseEntity
{
    public Guid OrderId { get; set; }
    public Guid ProductId { get; set; }
    
    public string ProductName { get; set; } = string.Empty; // Snapshot
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; } // Snapshot
    
    public decimal DiscountAmount { get; set; }
    public decimal TaxRate { get; set; }
    public decimal TaxAmount { get; set; }
    
    public decimal Subtotal { get; set; }
    public decimal Total { get; set; }
    
    public string? Notes { get; set; }
    public OrderItemStatus Status { get; set; }
    public DateTime? SentToKitchenAt { get; set; }

    // Navigation properties
    public Order Order { get; set; } = null!;
    public Product Product { get; set; } = null!;
    public ICollection<OrderItemModifier> Modifiers { get; set; } = new List<OrderItemModifier>();
}
