using DashTab.Application.Features.Kitchen.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class KitchenController : ControllerBase
{
    private readonly IMediator _mediator;
    public KitchenController(IMediator mediator) => _mediator = mediator;

    [HttpGet("tickets")]
    public async Task<IActionResult> GetKitchenTickets()
    {
        var result = await _mediator.Send(new GetKitchenTicketsQuery());
        return result.IsSuccess ? Ok(result.Value) : BadRequest(result.Error);
    }
}
