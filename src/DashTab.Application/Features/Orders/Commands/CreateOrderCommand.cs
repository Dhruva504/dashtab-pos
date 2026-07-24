using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using AutoMapper;
using MediatR;
using Microsoft.EntityFrameworkCore;
using DashTab.Domain.Entities;
using DashTab.Domain.Enums;

namespace DashTab.Application.Features.Orders.Commands;

public record CreateOrderItemDto(Guid ProductId, int Quantity, string? Notes);

public record CreateOrderCommand(
    Guid? TableId,
    OrderType OrderType,
    List<CreateOrderItemDto> Items
) : IRequest<Result<Guid>>;

public class CreateOrderCommandHandler : IRequestHandler<CreateOrderCommand, Result<Guid>>
{
    private readonly IApplicationDbContext _context;

    public CreateOrderCommandHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Result<Guid>> Handle(CreateOrderCommand request, CancellationToken cancellationToken)
    {
        var order = new Order
        {
            OrderNumber = $"ORD-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString()[..4].ToUpper()}",
            OrderType = request.OrderType,
            Status = OrderStatus.Open,
            TableId = request.TableId,
        };

        decimal subtotal = 0;

        foreach (var item in request.Items)
        {
            var product = await _context.Products.FindAsync(new object[] { item.ProductId }, cancellationToken);
            if (product == null) continue;

            var orderItem = new OrderItem
            {
                ProductId = product.Id,
                ProductName = product.Name,
                Quantity = item.Quantity,
                UnitPrice = product.Price,
                Subtotal = product.Price * item.Quantity,
                Total = product.Price * item.Quantity,
                Notes = item.Notes,
                Status = OrderItemStatus.Pending
            };
            order.Items.Add(orderItem);
            subtotal += orderItem.Total;
        }

        order.Subtotal = subtotal;
        order.TaxAmount = subtotal * 0.10m;
        order.Total = subtotal + order.TaxAmount;

        // Create kitchen ticket
        var ticket = new KitchenTicket
        {
            TicketNumber = $"KT-{DateTime.UtcNow:HHmmss}",
            Status = KitchenTicketStatus.Pending,
        };
        order.KitchenTickets.Add(ticket);

        _context.Orders.Add(order);

        // Update table status if dine-in
        if (request.TableId.HasValue)
        {
            var table = await _context.Tables.FindAsync(new object[] { request.TableId.Value }, cancellationToken);
            if (table != null) table.Status = TableStatus.Occupied;
        }

        await _context.SaveChangesAsync(cancellationToken);

        return Result<Guid>.Success(order.Id);
    }
}
