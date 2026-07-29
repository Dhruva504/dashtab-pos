using MediatR;
using DashTab.Application.Common.Models;

namespace DashTab.Application.Features.Auth.Commands;

public record LoginCommand(string Username, string Password, string TenantSlug) : IRequest<Result<LoginResponse>>;

public record LoginResponse(
    string AccessToken,
    string RefreshToken,
    Guid UserId,
    string FullName,
    Guid TenantId,
    string TenantName
);
