namespace DashTab.Domain.Common;

/// <summary>
/// Marker interface for all entities with an Id.
/// </summary>
public interface IEntity
{
    Guid Id { get; set; }
}

/// <summary>
/// Interface for entities that track creation and modification metadata.
/// </summary>
public interface IAuditableEntity
{
    DateTime CreatedAt { get; set; }
    DateTime UpdatedAt { get; set; }
    string? CreatedBy { get; set; }
    string? UpdatedBy { get; set; }
}

/// <summary>
/// Interface for entities that support soft deletion.
/// </summary>
public interface ISoftDeletable
{
    DateTime? DeletedAt { get; set; }
    string? DeletedBy { get; set; }
    bool IsDeleted { get; }
}

/// <summary>
/// Interface for entities that are scoped to a specific tenant.
/// </summary>
public interface ITenantAware
{
    Guid TenantId { get; set; }
}
