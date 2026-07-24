using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Kitchen.Queries;

public record KitchenTicketDto
{
    public Guid Id { get; init; }
    public string TicketNumber { get; init; } = string.Empty;
    public KitchenTicketStatus Status { get; init; }
    public string OrderNumber { get; init; } = string.Empty;
    public string? TableName { get; init; }
    public DateTime CreatedAt { get; init; }
    public List<KitchenItemDto> Items { get; init; } = new();
}

public record KitchenItemDto
{
    public Guid Id { get; init; }
    public string ProductName { get; init; } = string.Empty;
    public int Quantity { get; init; }
    public string? Notes { get; init; }
    public OrderItemStatus Status { get; init; }
}

public record GetKitchenTicketsQuery : IRequest<Result<List<KitchenTicketDto>>>;

public class GetKitchenTicketsQueryHandler
    : IRequestHandler<GetKitchenTicketsQuery, Result<List<KitchenTicketDto>>>
{
    private readonly IApplicationDbContext _context;

    public GetKitchenTicketsQueryHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Result<List<KitchenTicketDto>>> Handle(
        GetKitchenTicketsQuery request, CancellationToken cancellationToken)
    {
        var tickets = await _context.KitchenTickets
            .Include(t => t.Order).ThenInclude(o => o.Items)
            .Include(t => t.Order).ThenInclude(o => o.Table)
            .Where(t => t.Status != KitchenTicketStatus.Served)
            .OrderBy(t => t.CreatedAt)
            .AsNoTracking()
            .Select(t => new KitchenTicketDto
            {
                Id = t.Id,
                TicketNumber = t.TicketNumber,
                Status = t.Status,
                OrderNumber = t.Order.OrderNumber,
                TableName = t.Order.Table != null ? t.Order.Table.Name : null,
                CreatedAt = t.CreatedAt,
                Items = t.Order.Items.Select(i => new KitchenItemDto
                {
                    Id = i.Id,
                    ProductName = i.ProductName,
                    Quantity = i.Quantity,
                    Notes = i.Notes,
                    Status = i.Status,
                }).ToList(),
            })
            .ToListAsync(cancellationToken);

        return Result<List<KitchenTicketDto>>.Success(tickets);
    }
}
