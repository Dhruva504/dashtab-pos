using DashTab.Domain.Common;

namespace DashTab.Domain.Entities;

public class Permission
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Module { get; set; } = string.Empty;

    // Navigation properties
    public ICollection<Role> Roles { get; set; } = new List<Role>();
}
