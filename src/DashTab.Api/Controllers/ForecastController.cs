using DashTab.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class ForecastController : ControllerBase
{
    private readonly IForecastService _forecastService;

    public ForecastController(IForecastService forecastService) => _forecastService = forecastService;

    [HttpPost]
    public async Task<IActionResult> ForecastSales([FromBody] ForecastRequest request)
    {
        var result = await _forecastService.ForecastSalesAsync(request.From, request.Days);
        return Ok(result);
    }
}

public record ForecastRequest
{
    public DateTime From { get; init; }
    public int Days { get; init; } = 7;
}
