using DashTab.Application.Common.Interfaces;
using DashTab.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Services;

public record InvoiceLineDto
{
    public string ProductName { get; init; } = string.Empty;
    public int Quantity { get; init; }
    public decimal UnitPrice { get; init; }
    public decimal Total { get; init; }
}

public record InvoiceDto
{
    public string InvoiceNumber { get; init; } = string.Empty;
    public DateTime InvoiceDate { get; init; }
    public string OrderNumber { get; init; } = string.Empty;
    public string? CustomerName { get; init; }
    public string? TableName { get; init; }
    public decimal Subtotal { get; init; }
    public decimal TaxAmount { get; init; }
    public decimal Total { get; init; }
    public List<InvoiceLineDto> Lines { get; init; } = new();
}

public interface IInvoiceService
{
    Task<InvoiceDto> GenerateInvoiceAsync(Guid orderId, string? customerName = null);
}

public class InvoiceService : IInvoiceService
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public InvoiceService(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<InvoiceDto> GenerateInvoiceAsync(Guid orderId, string? customerName = null)
    {
        var tenantId = _currentUser.TenantId
            ?? throw new UnauthorizedAccessException("Request is not associated with a tenant. Cannot access tenant-scoped data.");

        var order = await _context.Orders
            .Include(o => o.Items)
            .Include(o => o.Table)
            .FirstOrDefaultAsync(o => o.Id == orderId && o.TenantId == tenantId)
            ?? throw new InvalidOperationException($"Order {orderId} not found.");

        var invoiceNumber = $"INV-{order.OrderNumber}-{DateTime.UtcNow:yyyyMMddHHmmss}";

        return new InvoiceDto
        {
            InvoiceNumber = invoiceNumber,
            InvoiceDate = DateTime.UtcNow,
            OrderNumber = order.OrderNumber,
            CustomerName = customerName,
            TableName = order.Table?.Name,
            Subtotal = order.Subtotal,
            TaxAmount = order.TaxAmount,
            Total = order.Total,
            Lines = order.Items.Select(i => new InvoiceLineDto
            {
                ProductName = i.ProductName,
                Quantity = i.Quantity,
                UnitPrice = i.UnitPrice,
                Total = i.Total,
            }).ToList(),
        };
    }
}
