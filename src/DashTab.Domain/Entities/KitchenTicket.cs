using DashTab.Domain.Common;
using DashTab.Domain.Enums;

namespace DashTab.Domain.Entities;

public class KitchenTicket : BaseEntity
{
    public Guid OrderId { get; set; }
    public string TicketNumber { get; set; } = string.Empty;
    public KitchenTicketStatus Status { get; set; }
    public Guid? PrinterId { get; set; }
    
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public Order Order { get; set; } = null!;
}
