using DashTab.Application.Features.Floors.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FloorsController : ControllerBase
{
    private readonly IMediator _mediator;

    public FloorsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    public async Task<IActionResult> GetFloorsWithTables()
    {
        var result = await _mediator.Send(new GetFloorsWithTablesQuery());
        if (result.IsSuccess)
        {
            return Ok(result.Value);
        }
        return BadRequest(result.Error);
    }
}
