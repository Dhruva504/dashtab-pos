using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Users.Commands;

public record CreateUserCommand(
    string Username,
    string DisplayName,
    string Pin,
    Guid RoleId
) : IRequest<Result<Guid>>;

public class CreateUserCommandHandler : IRequestHandler<CreateUserCommand, Result<Guid>>
{
    private readonly IApplicationDbContext _context;
    public CreateUserCommandHandler(IApplicationDbContext context) => _context = context;

    public async Task<Result<Guid>> Handle(CreateUserCommand request, CancellationToken cancellationToken)
    {
        // Check for existing username
        var exists = await _context.Users.AnyAsync(
            u => u.Username == request.Username, cancellationToken);
        if (exists)
            return Result<Guid>.Failure("Username already exists.");

        var user = new User
        {
            Username = request.Username,
            FullName = request.DisplayName,
            PasswordHash = BCryptHash(request.Pin), // Simple hash for now
            IsActive = true,
        };

        var role = await _context.Roles.FindAsync(new object[] { request.RoleId }, cancellationToken);
        if (role != null) user.Roles.Add(role);

        _context.Users.Add(user);
        await _context.SaveChangesAsync(cancellationToken);
        return Result<Guid>.Success(user.Id);
    }

    private static string BCryptHash(string input)
    {
        // Placeholder — in production use BCrypt.Net or ASP.NET Identity
        return Convert.ToBase64String(
            System.Security.Cryptography.SHA256.HashData(
                System.Text.Encoding.UTF8.GetBytes(input)));
    }
}
