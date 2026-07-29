using DashTab.Application.Features.Auth.Commands;
using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Auth.Handlers;

public class LoginCommandHandler : IRequestHandler<LoginCommand, Result<LoginResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ITokenService _tokenService;

    public LoginCommandHandler(IApplicationDbContext context, ITokenService tokenService)
    {
        _context = context;
        _tokenService = tokenService;
    }

    public async Task<Result<LoginResponse>> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        // 1. Find tenant by slug (case-insensitive)
        var tenant = await _context.Tenants
            .AsNoTracking()
            .FirstOrDefaultAsync(
                t => t.Slug.ToLower() == request.TenantSlug.ToLower() && t.IsActive,
                cancellationToken);

        if (tenant == null)
            return Result<LoginResponse>.Failure("Restaurant not found. Check your Restaurant ID.");

        // 2. Find active user by username within that tenant
        var user = await _context.Users
            .IgnoreQueryFilters() // bypass global tenant filter so we can filter manually
            .FirstOrDefaultAsync(
                u => u.Username.ToLower() == request.Username.ToLower()
                     && u.TenantId == tenant.Id
                     && u.IsActive,
                cancellationToken);

        if (user == null)
            return Result<LoginResponse>.Failure("Invalid username or password.");

        // 3. Verify password using ASP.NET Identity PasswordHasher
        var hasher = new PasswordHasher<string>();
        var verificationResult = hasher.VerifyHashedPassword("user", user.PasswordHash, request.Password);

        if (verificationResult == PasswordVerificationResult.Failed)
            return Result<LoginResponse>.Failure("Invalid username or password.");

        // 4. Generate tokens
        var accessToken = _tokenService.GenerateAccessToken(user);
        var refreshToken = _tokenService.GenerateRefreshToken();

        return Result<LoginResponse>.Success(new LoginResponse(
            AccessToken: accessToken,
            RefreshToken: refreshToken,
            UserId: user.Id,
            FullName: user.FullName ?? user.Username,
            TenantId: tenant.Id,
            TenantName: tenant.Name
        ));
    }
}
