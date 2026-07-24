using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class User : SoftDeletableEntity
{
    public string? Email { get; set; }
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string? FullName { get; set; }
    public string? Pin { get; set; } // Quick login for POS
    public bool IsActive { get; set; } = true;
    public DateTime? LastLoginAt { get; set; }

    // Navigation properties
    public Tenant Tenant { get; set; } = null!;
    public ICollection<Role> Roles { get; set; } = new List<Role>();
}
