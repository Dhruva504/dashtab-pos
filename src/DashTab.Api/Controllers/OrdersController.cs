using DashTab.Application.Features.Orders.Commands;
using DashTab.Application.Features.Orders.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IMediator _mediator;
    public OrdersController(IMediator mediator) => _mediator = mediator;

    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderCommand command)
    {
        var result = await _mediator.Send(command);
        return result.IsSuccess ? Created("", new { orderId = result.Value }) : BadRequest(result.Error);
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetActiveOrders()
    {
        var result = await _mediator.Send(new GetActiveOrdersQuery());
        return result.IsSuccess ? Ok(result.Value) : BadRequest(result.Error);
    }

    [HttpPut("{orderId}/items/{itemId}/status")]
    public async Task<IActionResult> UpdateItemStatus(
        Guid orderId, Guid itemId, [FromBody] UpdateOrderItemStatusCommand command)
    {
        var result = await _mediator.Send(command with { OrderId = orderId, ItemId = itemId });
        return result.IsSuccess ? Ok() : BadRequest(result.Error);
    }
}
