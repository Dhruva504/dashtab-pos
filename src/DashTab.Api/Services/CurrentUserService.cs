using System.Security.Claims;
using DashTab.Application.Common.Interfaces;
using Microsoft.AspNetCore.Http;

namespace DashTab.Api.Services;

/// <summary>
/// Reads the current user and tenant from the caller's Supabase JWT.
/// The Supabase JWT carries the tenant_id inside app_metadata, e.g.:
///   { "sub": "<user-id>", "role": "authenticated", ...,
///     "app_metadata": { "tenant_id": "<tenant-uuid>", ... } }
/// </summary>
public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public Guid? UserId
    {
        get
        {
            var sub = _httpContextAccessor.HttpContext?.User
                ?.FindFirstValue(ClaimTypes.NameIdentifier);
            return Guid.TryParse(sub, out var id) ? id : null;
        }
    }

    public Guid? TenantId
    {
        get
        {
            var user = _httpContextAccessor.HttpContext?.User;
            if (user is null) return null;

            // Supabase puts tenant_id in the app_metadata claim, which is serialized as JSON.
            // It may appear at the top level OR nested under app_metadata.
            var tenantClaim = user.FindFirst("tenant_id")?.Value
                ?? user.FindFirst("app_metadata")?.Value;

            if (tenantClaim is null) return null;

            // If we got the raw app_metadata JSON, try to parse the tenant_id field.
            if (Guid.TryParse(tenantClaim, out var topLevel) && IsUuid(tenantClaim))
                return topLevel;

            // app_metadata is a JSON object like { "tenant_id": "<uuid>", "full_name": "..." }
            try
            {
                using var doc = System.Text.Json.JsonDocument.Parse(tenantClaim);
                var root = doc.RootElement;
                if (root.ValueKind == System.Text.Json.JsonValueKind.Object
                    && root.TryGetProperty("tenant_id", out var tenantProp))
                {
                    var value = tenantProp.GetString();
                    if (Guid.TryParse(value, out var nested))
                        return nested;
                }
            }
            catch
            {
                // Ignore malformed JSON; fall through to null.
            }

            return null;
        }
    }

    private static bool IsUuid(string value)
        => Guid.TryParse(value, out _);
}
