using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class Category : SoftDeletableEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int SortOrder { get; set; } = 0;
    public string? Color { get; set; } // Hex color for POS buttons
    public string? Icon { get; set; }
    public bool IsActive { get; set; } = true;
    public Guid? ParentCategoryId { get; set; }

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public Category? ParentCategory { get; set; }
    public ICollection<Category> SubCategories { get; set; } = new List<Category>();
    public ICollection<Product> Products { get; set; } = new List<Product>();
}
