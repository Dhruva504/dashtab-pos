using DashTab.Application.Common.Interfaces;
using DashTab.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Services;

public record DailySalesDto
{
    public DateTime Date { get; init; }
    public decimal TotalRevenue { get; init; }
    public int OrderCount { get; init; }
    public decimal AverageTicketSize { get; init; }
    public decimal TotalTax { get; init; }
    public decimal TotalTips { get; init; }
}

public record MonthlySalesDto
{
    public int Year { get; init; }
    public int Month { get; init; }
    public decimal TotalRevenue { get; init; }
    public int OrderCount { get; init; }
    public decimal AverageTicketSize { get; init; }
}

public record ProductSalesDto
{
    public string ProductName { get; init; } = string.Empty;
    public int QuantitySold { get; init; }
    public decimal TotalRevenue { get; init; }
}

public interface IReportService
{
    Task<List<DailySalesDto>> GetDailySalesAsync(DateTime from, DateTime to);
    Task<List<MonthlySalesDto>> GetMonthlySalesAsync(DateTime from, DateTime to);
    Task<List<ProductSalesDto>> GetProductSalesAsync(DateTime from, DateTime to);
}

public class ReportService : IReportService
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ReportService(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<List<DailySalesDto>> GetDailySalesAsync(DateTime from, DateTime to)
    {
        var tenantId = RequireTenantId();

        // Normalize from/to to date range
        from = from.Date;
        to = to.Date.AddDays(1).AddTicks(-1);

        var report = await _context.Orders
            .Where(o => o.TenantId == tenantId)
            .Where(o => o.Status == OrderStatus.Paid || o.Status == OrderStatus.Closed)
            .Where(o => o.ClosedAt >= from && o.ClosedAt <= to)
            .GroupBy(o => o.ClosedAt!.Value.Date)
            .Select(g => new DailySalesDto
            {
                Date = g.Key,
                TotalRevenue = g.Sum(o => o.Total),
                OrderCount = g.Count(),
                AverageTicketSize = g.Average(o => o.Total),
                TotalTax = g.Sum(o => o.TaxAmount),
            })
            .OrderBy(r => r.Date)
            .AsNoTracking()
            .ToListAsync();

        return report;
    }

    public async Task<List<MonthlySalesDto>> GetMonthlySalesAsync(DateTime from, DateTime to)
    {
        var tenantId = RequireTenantId();

        from = from.Date;
        to = to.Date.AddDays(1).AddTicks(-1);

        var report = await _context.Orders
            .Where(o => o.TenantId == tenantId)
            .Where(o => o.Status == OrderStatus.Paid || o.Status == OrderStatus.Closed)
            .Where(o => o.ClosedAt >= from && o.ClosedAt <= to)
            .GroupBy(o => new { o.ClosedAt!.Value.Year, o.ClosedAt.Value.Month })
            .Select(g => new MonthlySalesDto
            {
                Year = g.Key.Year,
                Month = g.Key.Month,
                TotalRevenue = g.Sum(o => o.Total),
                OrderCount = g.Count(),
                AverageTicketSize = g.Average(o => o.Total),
            })
            .OrderBy(r => r.Year).ThenBy(r => r.Month)
            .AsNoTracking()
            .ToListAsync();

        return report;
    }

    public async Task<List<ProductSalesDto>> GetProductSalesAsync(DateTime from, DateTime to)
    {
        var tenantId = RequireTenantId();

        from = from.Date;
        to = to.Date.AddDays(1).AddTicks(-1);

        var report = await _context.OrderItems
            .Include(i => i.Order)
            .Where(i => i.TenantId == tenantId)
            .Where(i => i.Order.Status == OrderStatus.Paid || i.Order.Status == OrderStatus.Closed)
            .Where(i => i.Order.ClosedAt >= from && i.Order.ClosedAt <= to)
            .GroupBy(i => i.ProductName)
            .Select(g => new ProductSalesDto
            {
                ProductName = g.Key,
                QuantitySold = g.Sum(i => i.Quantity),
                TotalRevenue = g.Sum(i => i.Total),
            })
            .OrderByDescending(r => r.TotalRevenue)
            .AsNoTracking()
            .ToListAsync();

        return report;
    }

    private Guid RequireTenantId()
    {
        var tenantId = _currentUser.TenantId
            ?? throw new UnauthorizedAccessException("Request is not associated with a tenant. Cannot access tenant-scoped data.");
        return tenantId;
    }
}
