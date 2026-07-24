using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Reports.Queries;

public record DailySalesReportDto
{
    public DateTime Date { get; init; }
    public decimal TotalRevenue { get; init; }
    public int OrderCount { get; init; }
    public decimal AverageTicketSize { get; init; }
    public decimal TotalTax { get; init; }
    public decimal TotalTips { get; init; }
}

public record GetDailySalesReportQuery(DateTime From, DateTime To) : IRequest<Result<List<DailySalesReportDto>>>;

public class GetDailySalesReportQueryHandler
    : IRequestHandler<GetDailySalesReportQuery, Result<List<DailySalesReportDto>>>
{
    private readonly IApplicationDbContext _context;
    public GetDailySalesReportQueryHandler(IApplicationDbContext context) => _context = context;

    public async Task<Result<List<DailySalesReportDto>>> Handle(
        GetDailySalesReportQuery request, CancellationToken cancellationToken)
    {
        var report = await _context.Orders
            .Where(o => o.Status == OrderStatus.Paid || o.Status == OrderStatus.Closed)
            .Where(o => o.ClosedAt >= request.From && o.ClosedAt <= request.To)
            .GroupBy(o => o.ClosedAt!.Value.Date)
            .Select(g => new DailySalesReportDto
            {
                Date = g.Key,
                TotalRevenue = g.Sum(o => o.Total),
                OrderCount = g.Count(),
                AverageTicketSize = g.Average(o => o.Total),
                TotalTax = g.Sum(o => o.TaxAmount),
            })
            .OrderBy(r => r.Date)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        return Result<List<DailySalesReportDto>>.Success(report);
    }
}
