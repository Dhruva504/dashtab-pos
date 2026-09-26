using DashTab.Application.Common.Interfaces;
using DashTab.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Services;

public record ForecastDto
{
    public DateTime Date { get; init; }
    public decimal PredictedRevenue { get; init; }
    public int PredictedOrderCount { get; init; }
    public decimal Confidence { get; init; }
}

public interface IForecastService
{
    Task<List<ForecastDto>> ForecastSalesAsync(DateTime from, int days);
}

public class ForecastService : IForecastService
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ForecastService(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<List<ForecastDto>> ForecastSalesAsync(DateTime from, int days)
    {
        var tenantId = _currentUser.TenantId
            ?? throw new UnauthorizedAccessException("Request is not associated with a tenant. Cannot access tenant-scoped data.");

        // Simple moving average forecast based on historical data.
        // For production, use a more sophisticated model (e.g., linear regression, Prophet).
        var fromDate = from.Date.AddDays(-30); // Look back 30 days
        var toDate = from.Date.AddDays(days);

        var historical = await _context.Orders
            .Where(o => o.TenantId == tenantId)
            .Where(o => o.Status == OrderStatus.Paid || o.Status == OrderStatus.Closed)
            .Where(o => o.ClosedAt >= fromDate && o.ClosedAt < toDate)
            .GroupBy(o => o.ClosedAt!.Value.Date)
            .Select(g => new
            {
                Date = g.Key,
                Revenue = g.Sum(o => o.Total),
                Orders = g.Count(),
            })
            .AsNoTracking()
            .ToListAsync();

        if (historical.Count == 0)
        {
            return Enumerable.Range(0, days).Select(i => new ForecastDto
            {
                Date = from.Date.AddDays(i),
                PredictedRevenue = 0,
                PredictedOrderCount = 0,
                Confidence = 0,
            }).ToList();
        }

        var avgRevenue = historical.Average(h => h.Revenue);
        var avgOrders = (int)Math.Round(historical.Average(h => h.Orders));

        return Enumerable.Range(0, days).Select(i => new ForecastDto
        {
            Date = from.Date.AddDays(i),
            PredictedRevenue = Math.Round(avgRevenue, 2),
            PredictedOrderCount = avgOrders,
            Confidence = 0.7m, // Simple heuristic
        }).ToList();
    }
}
