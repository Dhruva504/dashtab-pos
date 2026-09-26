using DashTab.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DashTab.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class NotificationController : ControllerBase
{
    private readonly INotificationService _notificationService;

    public NotificationController(INotificationService notificationService) => _notificationService = notificationService;

    [HttpPost("send")]
    public async Task<IActionResult> Send([FromBody] NotificationRequest request)
    {
        var result = await _notificationService.SendAsync(request);
        return result.Success ? Ok(result) : BadRequest(result);
    }
}
