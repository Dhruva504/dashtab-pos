using DashTab.Application.Common.Models;
using DashTab.Application.Features.Floors.DTOs;
using DashTab.Domain.Interfaces;
using DashTab.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;
using AutoMapper;

namespace DashTab.Application.Features.Floors.Queries;

public record GetFloorsWithTablesQuery : IRequest<Result<List<FloorDto>>>;

public class GetFloorsWithTablesQueryHandler : IRequestHandler<GetFloorsWithTablesQuery, Result<List<FloorDto>>>
{
    private readonly IApplicationDbContext _context;
    private readonly IMapper _mapper;

    public GetFloorsWithTablesQueryHandler(IApplicationDbContext context, IMapper mapper)
    {
        _context = context;
        _mapper = mapper;
    }

    public async Task<Result<List<FloorDto>>> Handle(GetFloorsWithTablesQuery request, CancellationToken cancellationToken)
    {
        var floors = await _context.Floors
            .Include(f => f.Tables)
            .Where(f => f.IsActive)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        var floorDtos = _mapper.Map<List<FloorDto>>(floors);

        return Result<List<FloorDto>>.Success(floorDtos);
    }
}
