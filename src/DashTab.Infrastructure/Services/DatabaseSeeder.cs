using DashTab.Infrastructure.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace DashTab.Infrastructure.Services;

/// <summary>
/// Runs at startup to fix placeholder password hashes left in test/seed data.
/// Also applies any pending EF migrations automatically.
/// </summary>
public static class DatabaseSeeder
{
    public static async Task SeedAsync(IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<DashTabDbContext>>();

        try
        {
            var context = scope.ServiceProvider.GetRequiredService<DashTabDbContext>();

            // Apply pending migrations
            var pending = await context.Database.GetPendingMigrationsAsync();
            if (pending.Any())
            {
                logger.LogInformation("Applying {Count} pending migration(s)...", pending.Count());
                await context.Database.MigrateAsync();
                logger.LogInformation("Migrations applied.");
            }

            // Fix placeholder password hashes
            // The test data file uses 'hashed_password_string_here' as a placeholder.
            // We replace it with a real hash for the default demo password 'demo1234'.
            var hasher = new PasswordHasher<string>();
            var demoHash = hasher.HashPassword("user", "demo1234");

            // Use raw SQL to avoid tenant-filter complications during seeding
            var usersWithPlaceholder = await context.Users
                .IgnoreQueryFilters()
                .Where(u => u.PasswordHash == "hashed_password_string_here")
                .ToListAsync();

            if (usersWithPlaceholder.Count > 0)
            {
                foreach (var user in usersWithPlaceholder)
                {
                    user.PasswordHash = demoHash;
                    logger.LogInformation("Seeded password hash for user '{Username}'", user.Username);
                }
                await context.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Database seeding failed: {Message}", ex.Message);
            // Don't rethrow — let app start even if seeding fails
        }
    }
}
