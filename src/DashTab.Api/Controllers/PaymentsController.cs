using DashTab.Application.Features.Payments.Commands;
using DashTab.Application.Features.Payments.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PaymentsController : ControllerBase
{
    private readonly IMediator _mediator;
    public PaymentsController(IMediator mediator) => _mediator = mediator;

    [HttpPost]
    public async Task<IActionResult> ProcessPayment([FromBody] ProcessPaymentCommand command)
    {
        var result = await _mediator.Send(command);
        return result.IsSuccess ? Ok(new { paymentId = result.Value }) : BadRequest(result.Error);
    }

    [HttpGet("methods")]
    public async Task<IActionResult> GetPaymentMethods()
    {
        var result = await _mediator.Send(new GetPaymentMethodsQuery());
        return result.IsSuccess ? Ok(result.Value) : BadRequest(result.Error);
    }
}
