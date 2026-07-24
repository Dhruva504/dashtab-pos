using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class Tenant : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string CurrencyCode { get; set; } = "EUR";
    public string Locale { get; set; } = "es-ES";
    public string Timezone { get; set; } = "Europe/Madrid";
    public string? LogoUrl { get; set; }
    public bool IsActive { get; set; } = true;
    
    // Navigation properties
    public ICollection<User> Users { get; set; } = new List<User>();
    public ICollection<Role> Roles { get; set; } = new List<Role>();
}
