using DashTab.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Common.Interfaces;

public interface IApplicationDbContext
{
    DbSet<Tenant> Tenants { get; }
    DbSet<Floor> Floors { get; }
    DbSet<Table> Tables { get; }
    DbSet<Category> Categories { get; }
    DbSet<Product> Products { get; }
    DbSet<ModifierGroup> ModifierGroups { get; }
    DbSet<Modifier> Modifiers { get; }
    DbSet<Order> Orders { get; }
    DbSet<OrderItem> OrderItems { get; }
    DbSet<KitchenTicket> KitchenTickets { get; }
    DbSet<Payment> Payments { get; }
    DbSet<PaymentMethod> PaymentMethods { get; }
    DbSet<User> Users { get; }
    DbSet<Role> Roles { get; }
    
    Task<int> SaveChangesAsync(CancellationToken cancellationToken);
}

