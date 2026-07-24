using DashTab.Domain.Interfaces;

namespace DashTab.Infrastructure.MultiTenancy;

public class TenantContext : ITenantContext
{
    private Guid? _tenantId;

    public Guid? TenantId => _tenantId;

    public void SetTenantId(Guid tenantId)
    {
        if (_tenantId.HasValue && _tenantId.Value != tenantId)
        {
            throw new InvalidOperationException("Tenant ID is already set for this context.");
        }

        _tenantId = tenantId;
    }
}
