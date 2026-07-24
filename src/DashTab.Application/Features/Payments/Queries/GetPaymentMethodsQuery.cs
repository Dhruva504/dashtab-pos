using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Payments.Queries;

public record PaymentMethodDto(Guid Id, string Name, PaymentMethodType Type);

public record GetPaymentMethodsQuery : IRequest<Result<List<PaymentMethodDto>>>;

public class GetPaymentMethodsQueryHandler
    : IRequestHandler<GetPaymentMethodsQuery, Result<List<PaymentMethodDto>>>
{
    private readonly IApplicationDbContext _context;
    public GetPaymentMethodsQueryHandler(IApplicationDbContext context) => _context = context;

    public async Task<Result<List<PaymentMethodDto>>> Handle(
        GetPaymentMethodsQuery request, CancellationToken cancellationToken)
    {
        var methods = await _context.PaymentMethods
            .AsNoTracking()
            .Select(m => new PaymentMethodDto(m.Id, m.Name, m.Type))
            .ToListAsync(cancellationToken);

        return Result<List<PaymentMethodDto>>.Success(methods);
    }
}
