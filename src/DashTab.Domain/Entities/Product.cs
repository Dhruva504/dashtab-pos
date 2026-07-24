using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class Product : SoftDeletableEntity
{
    public Guid CategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? ShortName { get; set; } // For kitchen tickets
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public decimal? Cost { get; set; } // For profit calculation
    public string? Sku { get; set; }
    public string? Barcode { get; set; }
    public string? ImageUrl { get; set; }
    public int SortOrder { get; set; } = 0;
    public string? Color { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsAvailable { get; set; } = true; // Can be sold now
    public Guid? TaxRateId { get; set; }
    public Guid? KitchenPrinterId { get; set; } // Which printer to send KOT
    public int? PrepTimeMinutes { get; set; }

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public Category Category { get; set; } = null!;
    public TaxRate? TaxRate { get; set; }
    public ICollection<ModifierGroup> ModifierGroups { get; set; } = new List<ModifierGroup>();
}
