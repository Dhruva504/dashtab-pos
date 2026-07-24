using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class AuditLog : BaseEntity
{
    public Guid? UserId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;
    public string EntityId { get; set; } = string.Empty;
    public string? OldValues { get; set; } // Stored as JSON string
    public string? NewValues { get; set; } // Stored as JSON string
    public string? IpAddress { get; set; }

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public User? User { get; set; }
}
