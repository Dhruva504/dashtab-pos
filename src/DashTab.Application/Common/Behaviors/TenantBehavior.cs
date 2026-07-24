using MediatR;
using DashTab.Domain.Interfaces;

namespace DashTab.Application.Common.Behaviors;

public class TenantBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private readonly ITenantContext _tenantContext;

    public TenantBehavior(ITenantContext tenantContext)
    {
        _tenantContext = tenantContext;
    }

    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken cancellationToken)
    {
        // Add any tenant-specific validation or context manipulation here
        // The actual tenant ID resolution happens in the middleware, 
        // but this behavior can ensure it's present for certain requests if needed.
        
        return await next();
    }
}
