using Microsoft.EntityFrameworkCore;
using DashTab.Domain.Entities;
using DashTab.Domain.Common;
using DashTab.Domain.Interfaces;
using DashTab.Application.Common.Interfaces;
using System.Reflection;

namespace DashTab.Infrastructure.Data;

public class DashTabDbContext : DbContext, IApplicationDbContext
{
    private readonly ITenantContext _tenantContext;
    private readonly IDateTimeProvider _dateTimeProvider;

    public DashTabDbContext(
        DbContextOptions<DashTabDbContext> options,
        ITenantContext tenantContext,
        IDateTimeProvider dateTimeProvider) : base(options)
    {
        _tenantContext = tenantContext;
        _dateTimeProvider = dateTimeProvider;
    }

    public DbSet<Tenant> Tenants => Set<Tenant>();
    public DbSet<User> Users => Set<User>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Permission> Permissions => Set<Permission>();
    
    public DbSet<Floor> Floors => Set<Floor>();
    public DbSet<Table> Tables => Set<Table>();
    
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<ModifierGroup> ModifierGroups => Set<ModifierGroup>();
    public DbSet<Modifier> Modifiers => Set<Modifier>();
    
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderItem> OrderItems => Set<OrderItem>();
    public DbSet<OrderItemModifier> OrderItemModifiers => Set<OrderItemModifier>();
    public DbSet<KitchenTicket> KitchenTickets => Set<KitchenTicket>();
    
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<PaymentMethod> PaymentMethods => Set<PaymentMethod>();
    
    public DbSet<TaxRate> TaxRates => Set<TaxRate>();
    public DbSet<Discount> Discounts => Set<Discount>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        
        // Apply configurations from assembly
        modelBuilder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());

        // Apply Global Query Filters for Multi-Tenancy and Soft Delete
        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            if (typeof(ITenantAware).IsAssignableFrom(entityType.ClrType))
            {
                var method = typeof(DashTabDbContext)
                    .GetMethod(nameof(SetGlobalQueryFilters), BindingFlags.NonPublic | BindingFlags.Instance)
                    ?.MakeGenericMethod(entityType.ClrType);
                
                method?.Invoke(this, new object[] { modelBuilder });
            }
        }
    }

    private void SetGlobalQueryFilters<TEntity>(ModelBuilder modelBuilder) where TEntity : class, ITenantAware
    {
        modelBuilder.Entity<TEntity>().HasQueryFilter(e => 
            _tenantContext.TenantId == null || e.TenantId == _tenantContext.TenantId);
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = _dateTimeProvider.UtcNow;
                    entry.Entity.UpdatedAt = _dateTimeProvider.UtcNow;
                    if (entry.Entity is ITenantAware tenantAware && _tenantContext.TenantId.HasValue)
                    {
                        tenantAware.TenantId = _tenantContext.TenantId.Value;
                    }
                    break;
                case EntityState.Modified:
                    entry.Entity.UpdatedAt = _dateTimeProvider.UtcNow;
                    break;
            }
        }
        
        foreach (var entry in ChangeTracker.Entries<SoftDeletableEntity>())
        {
            if (entry.State == EntityState.Deleted)
            {
                entry.State = EntityState.Modified;
                entry.Entity.DeletedAt = _dateTimeProvider.UtcNow;
            }
        }

        return await base.SaveChangesAsync(cancellationToken);
    }
}
