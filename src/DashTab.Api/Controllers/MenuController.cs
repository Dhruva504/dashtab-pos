using DashTab.Application.Features.Menu.Commands;
using DashTab.Application.Features.Menu.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MenuController : ControllerBase
{
    private readonly IMediator _mediator;

    public MenuController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet("categories")]
    public async Task<IActionResult> GetCategoriesWithProducts()
    {
        var result = await _mediator.Send(new GetCategoriesWithProductsQuery());
        return result.IsSuccess ? Ok(result.Value) : BadRequest(result.Error);
    }

    [HttpPost("categories")]
    public async Task<IActionResult> CreateCategory([FromBody] CreateCategoryCommand command)
    {
        var result = await _mediator.Send(command);
        return result.IsSuccess ? Created("", result.Value) : BadRequest(result.Error);
    }

    [HttpPost("products")]
    public async Task<IActionResult> CreateProduct([FromBody] CreateProductCommand command)
    {
        var result = await _mediator.Send(command);
        return result.IsSuccess ? Created("", result.Value) : BadRequest(result.Error);
    }
}
