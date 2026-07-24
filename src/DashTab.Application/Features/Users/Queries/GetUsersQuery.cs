using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Users.Queries;

public record UserDto(Guid Id, string Username, string DisplayName, string RoleName, bool IsActive);

public record GetUsersQuery : IRequest<Result<List<UserDto>>>;

public class GetUsersQueryHandler : IRequestHandler<GetUsersQuery, Result<List<UserDto>>>
{
    private readonly IApplicationDbContext _context;
    public GetUsersQueryHandler(IApplicationDbContext context) => _context = context;

    public async Task<Result<List<UserDto>>> Handle(GetUsersQuery request, CancellationToken cancellationToken)
    {
        var users = await _context.Users
            .Include(u => u.Roles)
            .AsNoTracking()
            .Select(u => new UserDto(u.Id, u.Username, u.FullName ?? "", u.Roles.FirstOrDefault() != null ? u.Roles.FirstOrDefault()!.Name : "No Role", u.IsActive))
            .ToListAsync(cancellationToken);

        return Result<List<UserDto>>.Success(users);
    }
}
