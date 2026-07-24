using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Application.Features.Menu.DTOs;
using AutoMapper;
using MediatR;

namespace DashTab.Application.Features.Menu.Commands;

public record CreateCategoryCommand(
    string Name,
    string? Description,
    string? Color,
    string? Icon,
    int SortOrder
) : IRequest<Result<CategoryDto>>;

public class CreateCategoryCommandHandler
    : IRequestHandler<CreateCategoryCommand, Result<CategoryDto>>
{
    private readonly IApplicationDbContext _context;
    private readonly IMapper _mapper;

    public CreateCategoryCommandHandler(IApplicationDbContext context, IMapper mapper)
    {
        _context = context;
        _mapper = mapper;
    }

    public async Task<Result<CategoryDto>> Handle(
        CreateCategoryCommand request, CancellationToken cancellationToken)
    {
        var category = new DashTab.Domain.Entities.Category
        {
            Name = request.Name,
            Description = request.Description,
            Color = request.Color,
            Icon = request.Icon,
            SortOrder = request.SortOrder,
            IsActive = true
        };

        _context.Categories.Add(category);
        await _context.SaveChangesAsync(cancellationToken);

        return Result<CategoryDto>.Success(_mapper.Map<CategoryDto>(category));
    }
}
