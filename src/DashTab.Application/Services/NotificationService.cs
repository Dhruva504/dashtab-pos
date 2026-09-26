using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Net.Mail;

namespace DashTab.Application.Services;

public record NotificationRequest
{
    public string Channel { get; init; } = "email"; // email | whatsapp | sms
    public string To { get; init; } = string.Empty;
    public string Subject { get; init; } = string.Empty;
    public string Body { get; init; } = string.Empty;
}

public record NotificationResult
{
    public bool Success { get; init; }
    public string? Message { get; init; }
}

public interface INotificationService
{
    Task<NotificationResult> SendAsync(NotificationRequest request);
}

/// <summary>
/// Sends notifications over configured channels. Email is delivered via SMTP
/// when the Notifications:Smtp section is configured (host, port, from and
/// credentials). Channels without a provider configured fail loudly instead
/// of pretending the message was delivered.
/// </summary>
public class NotificationService : INotificationService
{
    private readonly ILogger<NotificationService> _logger;
    private readonly string? _host;
    private readonly int _port;
    private readonly string? _from;
    private readonly string? _username;
    private readonly string? _password;

    public NotificationService(ILogger<NotificationService> logger, IConfiguration configuration)
    {
        _logger = logger;
        _host = configuration["Notifications:Smtp:Host"];
        _port = configuration.GetValue("Notifications:Smtp:Port", 587);
        _from = configuration["Notifications:Smtp:From"];
        _username = configuration["Notifications:Smtp:Username"];
        _password = configuration["Notifications:Smtp:Password"];
    }

    public async Task<NotificationResult> SendAsync(NotificationRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.To))
        {
            return new NotificationResult { Success = false, Message = "Recipient is required." };
        }

        try
        {
            return request.Channel.ToLowerInvariant() switch
            {
                "email" => await SendEmailAsync(request),
                "whatsapp" => NotConfigured("WhatsApp (configure a WhatsApp Business API provider)"),
                "sms" => NotConfigured("SMS (configure a Twilio or similar SMS provider)"),
                _ => new NotificationResult { Success = false, Message = $"Unknown channel '{request.Channel}'." },
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send {Channel} notification to {To}", request.Channel, request.To);
            return new NotificationResult { Success = false, Message = ex.Message };
        }
    }

    private async Task<NotificationResult> SendEmailAsync(NotificationRequest request)
    {
        if (string.IsNullOrWhiteSpace(_host) || string.IsNullOrWhiteSpace(_from))
        {
            return NotConfigured("email SMTP (set Notifications:Smtp:Host/Port/From and credentials)");
        }

        using var client = new SmtpClient(_host, _port)
        {
            EnableSsl = true,
            Credentials = new NetworkCredential(_username, _password),
        };
        var message = new MailMessage(_from, request.To)
        {
            Subject = string.IsNullOrWhiteSpace(request.Subject) ? "DashTab POS" : request.Subject,
            Body = request.Body,
            IsBodyHtml = false,
        };
        await client.SendMailAsync(message);
        _logger.LogInformation("Email sent to {To} with subject '{Subject}'", request.To, request.Subject);
        return new NotificationResult
        {
            Success = true,
            Message = $"Email sent to {request.To}",
        };
    }

    private NotificationResult NotConfigured(string what)
        => new()
        {
            Success = false,
            Message = $"{what} is not configured on the server, so nothing was sent.",
        };
}
