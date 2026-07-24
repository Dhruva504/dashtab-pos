using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Domain.Entities;
using DashTab.Domain.Enums;
using MediatR;

namespace DashTab.Application.Features.Payments.Commands;

public record ProcessPaymentCommand(
    Guid OrderId,
    Guid PaymentMethodId,
    decimal Amount,
    decimal TipAmount
) : IRequest<Result<Guid>>;

public class ProcessPaymentCommandHandler : IRequestHandler<ProcessPaymentCommand, Result<Guid>>
{
    private readonly IApplicationDbContext _context;
    public ProcessPaymentCommandHandler(IApplicationDbContext context) => _context = context;

    public async Task<Result<Guid>> Handle(ProcessPaymentCommand request, CancellationToken cancellationToken)
    {
        var order = await _context.Orders.FindAsync(new object[] { request.OrderId }, cancellationToken);
        if (order == null) return Result<Guid>.Failure("Order not found.");

        var payment = new Payment
        {
            OrderId = request.OrderId,
            PaymentMethodId = request.PaymentMethodId,
            Amount = request.Amount,
            TipAmount = request.TipAmount,
            ChangeAmount = request.Amount > order.Total ? request.Amount - order.Total : 0,
            Status = PaymentStatus.Completed,
        };

        _context.Payments.Add(payment);

        // Update order status
        order.Status = request.Amount >= order.Total ? OrderStatus.Paid : OrderStatus.PartiallyPaid;
        if (order.Status == OrderStatus.Paid) order.ClosedAt = DateTime.UtcNow;

        // Free table
        if (order.Status == OrderStatus.Paid && order.TableId.HasValue)
        {
            var table = await _context.Tables.FindAsync(new object[] { order.TableId.Value }, cancellationToken);
            if (table != null) table.Status = TableStatus.Dirty;
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Result<Guid>.Success(payment.Id);
    }
}
