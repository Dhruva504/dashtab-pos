using DashTab.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class InvoiceController : ControllerBase
{
    private readonly IInvoiceService _invoiceService;

    public InvoiceController(IInvoiceService invoiceService) => _invoiceService = invoiceService;

    [HttpPost]
    public async Task<IActionResult> GenerateInvoice([FromBody] GenerateInvoiceRequest request)
    {
        try
        {
            var result = await _invoiceService.GenerateInvoiceAsync(request.OrderId, request.CustomerName);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(ex.Message);
        }
    }
}

public record GenerateInvoiceRequest
{
    public Guid OrderId { get; init; }
    public string? CustomerName { get; init; }
}
