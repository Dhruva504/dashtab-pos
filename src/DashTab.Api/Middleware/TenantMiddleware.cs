using DashTab.Domain.Interfaces;

namespace DashTab.Api.Middleware;

public class TenantMiddleware
{
    private readonly RequestDelegate _next;

    public TenantMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, ITenantContext tenantContext)
    {
        // Example: extract tenant from header "X-Tenant-Id"
        if (context.Request.Headers.TryGetValue("X-Tenant-Id", out var tenantIdString) && 
            Guid.TryParse(tenantIdString, out var tenantId))
        {
            tenantContext.SetTenantId(tenantId);
        }
        // In a real scenario, this could also come from JWT claims or subdomains

        await _next(context);
    }
}

public static class TenantMiddlewareExtensions
{
    public static IApplicationBuilder UseTenantMiddleware(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<TenantMiddleware>();
    }
}
