using DashTab.Application.Common.Interfaces;
using DashTab.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Services;

public record TaxBreakdownDto
{
    public decimal Subtotal { get; init; }
    public decimal TotalTax { get; init; }
    public decimal Total { get; init; }
    public List<TaxLineDto> TaxLines { get; init; } = new();
}

public record TaxLineDto
{
    public string RateName { get; init; } = string.Empty;
    public decimal Rate { get; init; }
    public decimal TaxableAmount { get; init; }
    public decimal TaxAmount { get; init; }
}

public interface ITaxService
{
    Task<TaxBreakdownDto> CalculateTaxAsync(IEnumerable<(string ProductName, decimal Amount, decimal Quantity)> items);
    decimal CalculateTax(decimal amount, decimal ratePercent);
}

public class TaxService : ITaxService
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public TaxService(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<TaxBreakdownDto> CalculateTaxAsync(
        IEnumerable<(string ProductName, decimal Amount, decimal Quantity)> items)
    {
        var tenantId = _currentUser.TenantId
            ?? throw new UnauthorizedAccessException("Request is not associated with a tenant. Cannot access tenant-scoped data.");

        var taxableAmounts = items.ToList();
        var subtotal = taxableAmounts.Sum(i => i.Amount);

        // Fetch active tax rates
        var taxRates = await _context.TaxRates
            .Where(t => t.TenantId == tenantId)
            .AsNoTracking()
            .ToListAsync();

        var taxLines = new List<TaxLineDto>();
        foreach (var rate in taxRates)
        {
            // Apply tax rate to the taxable amount (assume all items are taxable)
            var taxableAmount = subtotal;
            var taxAmount = CalculateTax(taxableAmount, rate.Rate);

            taxLines.Add(new TaxLineDto
            {
                RateName = rate.Name,
                Rate = rate.Rate,
                TaxableAmount = taxableAmount,
                TaxAmount = taxAmount,
            });
        }

        var totalTax = taxLines.Sum(t => t.TaxAmount);

        return new TaxBreakdownDto
        {
            Subtotal = subtotal,
            TotalTax = totalTax,
            Total = subtotal + totalTax,
            TaxLines = taxLines,
        };
    }

    public decimal CalculateTax(decimal amount, decimal ratePercent)
    {
        return decimal.Round(amount * ratePercent / 100m, 2);
    }
}
