using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Domain.Enums;
using MediatR;

namespace DashTab.Application.Features.Orders.Commands;

public record UpdateOrderItemStatusCommand(
    Guid OrderId,
    Guid ItemId,
    OrderItemStatus NewStatus
) : IRequest<Result<bool>>;

public class UpdateOrderItemStatusCommandHandler
    : IRequestHandler<UpdateOrderItemStatusCommand, Result<bool>>
{
    private readonly IApplicationDbContext _context;

    public UpdateOrderItemStatusCommandHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Result<bool>> Handle(
        UpdateOrderItemStatusCommand request, CancellationToken cancellationToken)
    {
        var item = await _context.OrderItems.FindAsync(
            new object[] { request.ItemId }, cancellationToken);

        if (item == null || item.OrderId != request.OrderId)
            return Result<bool>.Failure("Order item not found.");

        item.Status = request.NewStatus;
        if (request.NewStatus == OrderItemStatus.SentToKitchen)
            item.SentToKitchenAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);
        return Result<bool>.Success(true);
    }
}
