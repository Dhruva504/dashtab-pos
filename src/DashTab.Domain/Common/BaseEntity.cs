namespace DashTab.Domain.Common;

/// <summary>
/// Base entity that all domain entities inherit from.
/// Provides multi-tenancy support, auditing, and soft delete capabilities.
/// </summary>
public abstract class BaseEntity : IEntity, IAuditableEntity, ITenantAware
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid TenantId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>
/// Base entity with soft delete support.
/// </summary>
public abstract class SoftDeletableEntity : BaseEntity, ISoftDeletable
{
    public DateTime? DeletedAt { get; set; }
    public string? DeletedBy { get; set; }
    public bool IsDeleted => DeletedAt.HasValue;
}
