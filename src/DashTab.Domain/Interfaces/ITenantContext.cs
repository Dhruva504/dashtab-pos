namespace DashTab.Domain.Interfaces;

public interface ITenantContext
{
    Guid? TenantId { get; }
    void SetTenantId(Guid tenantId);
}
