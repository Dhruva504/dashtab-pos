using Microsoft.Extensions.Logging;

namespace DashTab.Application.Services;

public record IntegrationRequest
{
    public string Provider { get; init; } = string.Empty; // swiggy, zomato, payment-gateway, ...
    public string Operation { get; init; } = string.Empty; // push, pull, sync
    public Dictionary<string, object> Payload { get; init; } = new();
}

public record IntegrationResult
{
    public bool Success { get; init; }
    public string? Message { get; init; }
    public Dictionary<string, object>? Data { get; init; }
}

public interface IIntegrationService
{
    Task<IntegrationResult> ExecuteAsync(IntegrationRequest request);
}

/// <summary>
/// Integration hub for third-party providers (aggregators, payment gateways,
/// accounting/ERP). No provider credentials are bundled with the product:
/// until one is configured the service reports explicitly that it is not
/// wired up, rather than pretending the operation succeeded.
/// </summary>
public class IntegrationService : IIntegrationService
{
    private readonly ILogger<IntegrationService> _logger;

    public IntegrationService(ILogger<IntegrationService> logger) => _logger = logger;

    public Task<IntegrationResult> ExecuteAsync(IntegrationRequest request)
    {
        _logger.LogInformation(
            "Integration requested: {Provider} {Operation} ({ItemCount} payload items)",
            request.Provider, request.Operation, request.Payload.Count);

        return Task.FromResult(new IntegrationResult
        {
            Success = false,
            Message = $"No integration is configured for provider '{request.Provider}'. " +
                      "Add the provider credentials on the server to enable it.",
        });
    }
}
