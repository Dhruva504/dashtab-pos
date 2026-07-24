using DashTab.Domain.Common;
using DashTab.Domain.Enums;

namespace DashTab.Domain.Entities;

public class Payment : BaseEntity
{
    public Guid OrderId { get; set; }
    public Guid PaymentMethodId { get; set; }
    
    public decimal Amount { get; set; }
    public decimal TipAmount { get; set; } = 0;
    public decimal ChangeAmount { get; set; } = 0;
    
    public PaymentStatus Status { get; set; }
    public string? Reference { get; set; }

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public Order Order { get; set; } = null!;
    public PaymentMethod PaymentMethod { get; set; } = null!;
}
