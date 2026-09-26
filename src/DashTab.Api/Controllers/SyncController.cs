using DashTab.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class SyncController : ControllerBase
{
    private readonly IIntegrationService _integrationService;

    public SyncController(IIntegrationService integrationService) => _integrationService = integrationService;

    [HttpPost]
    public async Task<IActionResult> Execute([FromBody] IntegrationRequest request)
    {
        var result = await _integrationService.ExecuteAsync(request);
        return result.Success ? Ok(result) : BadRequest(result);
    }
}
