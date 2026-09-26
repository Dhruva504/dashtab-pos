using DashTab.Application.Common.Interfaces;
using DashTab.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Services;

public record DashboardMetricsDto
{
    public decimal TodaySales { get; init; }
    public int TodayOrderCount { get; init; }
    public decimal AverageTicketSize { get; init; }
    public List<PopularProductDto> PopularProducts { get; init; } = new();
    public List<PeakHourDto> PeakHours { get; init; } = new();
    public List<StaffPerformanceDto> StaffPerformance { get; init; } = new();
}

public record PopularProductDto
{
    public string ProductName { get; init; } = string.Empty;
    public int QuantitySold { get; init; }
    public decimal TotalRevenue { get; init; }
}

public record PeakHourDto
{
    public int Hour { get; init; }
    public int OrderCount { get; init; }
    public decimal TotalRevenue { get; init; }
}

public record StaffPerformanceDto
{
    public Guid StaffId { get; init; }
    public string StaffName { get; init; } = string.Empty;
    public int OrderCount { get; init; }
    public decimal TotalRevenue { get; init; }
}

public interface IAnalyticsService
{
    Task<DashboardMetricsDto> GetDashboardMetricsAsync(DateTime? date = null);
}

public class AnalyticsService : IAnalyticsService
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public AnalyticsService(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<DashboardMetricsDto> GetDashboardMetricsAsync(DateTime? date = null)
    {
        var tenantId = RequireTenantId();
        var targetDate = (date ?? DateTime.UtcNow).Date;
        var nextDay = targetDate.AddDays(1);

        // Today's sales
        var todayOrders = await _context.Orders
            .Where(o => o.TenantId == tenantId)
            .Where(o => o.Status == OrderStatus.Paid || o.Status == OrderStatus.Closed)
            .Where(o => o.ClosedAt >= targetDate && o.ClosedAt < nextDay)
            .AsNoTracking()
            .ToListAsync();

        var todaySales = todayOrders.Sum(o => o.Total);
        var todayOrderCount = todayOrders.Count;
        var avgTicket = todayOrderCount > 0 ? todaySales / todayOrderCount : 0;

        // Popular products (last 7 days)
        var from7Days = targetDate.AddDays(-7);
        var popularProducts = await _context.OrderItems
            .Include(i => i.Order)
            .Where(i => i.TenantId == tenantId)
            .Where(i => i.Order.Status == OrderStatus.Paid || i.Order.Status == OrderStatus.Closed)
            .Where(i => i.Order.ClosedAt >= from7Days && i.Order.ClosedAt < nextDay)
            .GroupBy(i => i.ProductName)
            .Select(g => new PopularProductDto
            {
                ProductName = g.Key,
                QuantitySold = g.Sum(i => i.Quantity),
                TotalRevenue = g.Sum(i => i.Total),
            })
            .OrderByDescending(r => r.QuantitySold)
            .Take(5)
            .AsNoTracking()
            .ToListAsync();

        // Peak hours (today)
        var peakHours = await _context.Orders
            .Where(o => o.TenantId == tenantId)
            .Where(o => o.Status == OrderStatus.Paid || o.Status == OrderStatus.Closed)
            .Where(o => o.ClosedAt >= targetDate && o.ClosedAt < nextDay)
            .GroupBy(o => o.ClosedAt!.Value.Hour)
            .Select(g => new PeakHourDto
            {
                Hour = g.Key,
                OrderCount = g.Count(),
                TotalRevenue = g.Sum(o => o.Total),
            })
            .OrderByDescending(r => r.OrderCount)
            .Take(8)
            .AsNoTracking()
            .ToListAsync();

        // Staff performance (today)
        var staffPerformance = await _context.Orders
            .Where(o => o.TenantId == tenantId)
            .Where(o => o.Status == OrderStatus.Paid || o.Status == OrderStatus.Closed)
            .Where(o => o.ClosedAt >= targetDate && o.ClosedAt < nextDay)
            .Where(o => o.WaiterId != null)
            .GroupBy(o => new { o.WaiterId!.Value, o.Waiter!.FullName })
            .Select(g => new StaffPerformanceDto
            {
                StaffId = g.Key.Value,
                StaffName = g.Key.FullName ?? "Unknown",
                OrderCount = g.Count(),
                TotalRevenue = g.Sum(o => o.Total),
            })
            .OrderByDescending(r => r.TotalRevenue)
            .AsNoTracking()
            .ToListAsync();

        return new DashboardMetricsDto
        {
            TodaySales = todaySales,
            TodayOrderCount = todayOrderCount,
            AverageTicketSize = avgTicket,
            PopularProducts = popularProducts,
            PeakHours = peakHours,
            StaffPerformance = staffPerformance,
        };
    }

    private Guid RequireTenantId()
    {
        var tenantId = _currentUser.TenantId
            ?? throw new UnauthorizedAccessException("Request is not associated with a tenant. Cannot access tenant-scoped data.");
        return tenantId;
    }
}
