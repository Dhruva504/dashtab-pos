using DashTab.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class ReportController : ControllerBase
{
    private readonly IReportService _reportService;

    public ReportController(IReportService reportService) => _reportService = reportService;

    [HttpPost("daily-sales")]
    public async Task<IActionResult> GetDailySales([FromBody] DateRangeRequest request)
    {
        var result = await _reportService.GetDailySalesAsync(request.From, request.To);
        return Ok(result);
    }

    [HttpPost("monthly-sales")]
    public async Task<IActionResult> GetMonthlySales([FromBody] DateRangeRequest request)
    {
        var result = await _reportService.GetMonthlySalesAsync(request.From, request.To);
        return Ok(result);
    }

    [HttpPost("product-sales")]
    public async Task<IActionResult> GetProductSales([FromBody] DateRangeRequest request)
    {
        var result = await _reportService.GetProductSalesAsync(request.From, request.To);
        return Ok(result);
    }
}

public record DateRangeRequest
{
    public DateTime From { get; init; }
    public DateTime To { get; init; }
}
