using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Application.Features.Menu.DTOs;
using AutoMapper;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace DashTab.Application.Features.Menu.Queries;

public record GetCategoriesWithProductsQuery : IRequest<Result<List<CategoryDto>>>;

public class GetCategoriesWithProductsQueryHandler
    : IRequestHandler<GetCategoriesWithProductsQuery, Result<List<CategoryDto>>>
{
    private readonly IApplicationDbContext _context;
    private readonly IMapper _mapper;

    public GetCategoriesWithProductsQueryHandler(IApplicationDbContext context, IMapper mapper)
    {
        _context = context;
        _mapper = mapper;
    }

    public async Task<Result<List<CategoryDto>>> Handle(
        GetCategoriesWithProductsQuery request, CancellationToken cancellationToken)
    {
        var categories = await _context.Categories
            .Include(c => c.Products.Where(p => p.IsActive && p.IsAvailable))
            .Where(c => c.IsActive)
            .OrderBy(c => c.SortOrder)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        var dtos = _mapper.Map<List<CategoryDto>>(categories);
        return Result<List<CategoryDto>>.Success(dtos);
    }
}
