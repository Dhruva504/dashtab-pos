using DashTab.Domain.Common;
using DashTab.Domain.Enums;

namespace DashTab.Domain.Entities;

public class Order : BaseEntity
{
    public string OrderNumber { get; set; } = string.Empty;
    public OrderType OrderType { get; set; }
    public OrderStatus Status { get; set; }
    
    public Guid? TableId { get; set; }
    public Guid? CustomerId { get; set; }
    public Guid? WaiterId { get; set; }

    public decimal Subtotal { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal Total { get; set; }
    
    public string? Notes { get; set; }
    public DateTime? ClosedAt { get; set; }

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public Table? Table { get; set; }
    public User? Waiter { get; set; }
    public ICollection<OrderItem> Items { get; set; } = new List<OrderItem>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    public ICollection<KitchenTicket> KitchenTickets { get; set; } = new List<KitchenTicket>();
}
