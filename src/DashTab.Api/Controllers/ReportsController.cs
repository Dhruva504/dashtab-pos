using DashTab.Application.Features.Reports.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReportsController : ControllerBase
{
    private readonly IMediator _mediator;
    public ReportsController(IMediator mediator) => _mediator = mediator;

    [HttpGet("daily-sales")]
    public async Task<IActionResult> GetDailySalesReport([FromQuery] DateTime from, [FromQuery] DateTime to)
    {
        var result = await _mediator.Send(new GetDailySalesReportQuery(from, to));
        return result.IsSuccess ? Ok(result.Value) : BadRequest(result.Error);
    }

    [HttpGet("product-sales")]
    public async Task<IActionResult> GetProductSalesReport([FromQuery] DateTime from, [FromQuery] DateTime to)
    {
        var result = await _mediator.Send(new GetProductSalesReportQuery(from, to));
        return result.IsSuccess ? Ok(result.Value) : BadRequest(result.Error);
    }
}
