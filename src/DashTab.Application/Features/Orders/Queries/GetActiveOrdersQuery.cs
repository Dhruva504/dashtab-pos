using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Orders.Queries;

public record OrderDto
{
    public Guid Id { get; init; }
    public string OrderNumber { get; init; } = string.Empty;
    public OrderType OrderType { get; init; }
    public OrderStatus Status { get; init; }
    public decimal Total { get; init; }
    public string? TableName { get; init; }
    public List<OrderItemDto> Items { get; init; } = new();
}

public record OrderItemDto
{
    public Guid Id { get; init; }
    public string ProductName { get; init; } = string.Empty;
    public int Quantity { get; init; }
    public decimal UnitPrice { get; init; }
    public decimal Total { get; init; }
    public string? Notes { get; init; }
    public OrderItemStatus Status { get; init; }
}

public record GetActiveOrdersQuery : IRequest<Result<List<OrderDto>>>;

public class GetActiveOrdersQueryHandler
    : IRequestHandler<GetActiveOrdersQuery, Result<List<OrderDto>>>
{
    private readonly IApplicationDbContext _context;

    public GetActiveOrdersQueryHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Result<List<OrderDto>>> Handle(
        GetActiveOrdersQuery request, CancellationToken cancellationToken)
    {
        var orders = await _context.Orders
            .Include(o => o.Items)
            .Include(o => o.Table)
            .Where(o => o.Status == OrderStatus.Open || o.Status == OrderStatus.PartiallyPaid)
            .AsNoTracking()
            .Select(o => new OrderDto
            {
                Id = o.Id,
                OrderNumber = o.OrderNumber,
                OrderType = o.OrderType,
                Status = o.Status,
                Total = o.Total,
                TableName = o.Table != null ? o.Table.Name : null,
                Items = o.Items.Select(i => new OrderItemDto
                {
                    Id = i.Id,
                    ProductName = i.ProductName,
                    Quantity = i.Quantity,
                    UnitPrice = i.UnitPrice,
                    Total = i.Total,
                    Notes = i.Notes,
                    Status = i.Status,
                }).ToList(),
            })
            .ToListAsync(cancellationToken);

        return Result<List<OrderDto>>.Success(orders);
    }
}
