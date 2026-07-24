using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class ModifierGroup : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public int MinSelections { get; set; } = 0;
    public int MaxSelections { get; set; } = 1;
    public bool IsRequired { get; set; } = false;
    public int SortOrder { get; set; } = 0;

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public ICollection<Modifier> Modifiers { get; set; } = new List<Modifier>();
    public ICollection<Product> Products { get; set; } = new List<Product>();
}
