using DashTab.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class AnalyticsController : ControllerBase
{
    private readonly IAnalyticsService _analyticsService;

    public AnalyticsController(IAnalyticsService analyticsService) => _analyticsService = analyticsService;

    [HttpPost("dashboard")]
    public async Task<IActionResult> GetDashboardMetrics([FromBody] DashboardMetricsRequest? request)
    {
        var result = await _analyticsService.GetDashboardMetricsAsync(request?.Date);
        return Ok(result);
    }
}

public record DashboardMetricsRequest
{
    public DateTime? Date { get; init; }
}
