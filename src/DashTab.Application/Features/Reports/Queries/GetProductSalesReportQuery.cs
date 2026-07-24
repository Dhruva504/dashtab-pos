using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Reports.Queries;

public record ProductSalesDto
{
    public string ProductName { get; init; } = string.Empty;
    public int QuantitySold { get; init; }
    public decimal TotalRevenue { get; init; }
}

public record GetProductSalesReportQuery(DateTime From, DateTime To) : IRequest<Result<List<ProductSalesDto>>>;

public class GetProductSalesReportQueryHandler
    : IRequestHandler<GetProductSalesReportQuery, Result<List<ProductSalesDto>>>
{
    private readonly IApplicationDbContext _context;
    public GetProductSalesReportQueryHandler(IApplicationDbContext context) => _context = context;

    public async Task<Result<List<ProductSalesDto>>> Handle(
        GetProductSalesReportQuery request, CancellationToken cancellationToken)
    {
        var report = await _context.OrderItems
            .Include(i => i.Order)
            .Where(i => i.Order.Status == OrderStatus.Paid || i.Order.Status == OrderStatus.Closed)
            .Where(i => i.Order.ClosedAt >= request.From && i.Order.ClosedAt <= request.To)
            .GroupBy(i => i.ProductName)
            .Select(g => new ProductSalesDto
            {
                ProductName = g.Key,
                QuantitySold = g.Sum(i => i.Quantity),
                TotalRevenue = g.Sum(i => i.Total),
            })
            .OrderByDescending(r => r.TotalRevenue)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        return Result<List<ProductSalesDto>>.Success(report);
    }
}
