using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class TaxRate : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public decimal Rate { get; set; }
    public bool IsInclusive { get; set; } = true;
    public bool IsDefault { get; set; } = false;
    public bool IsActive { get; set; } = true;

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
}
