using DashTab.Application.Common.Interfaces;
using DashTab.Application.Common.Models;
using DashTab.Application.Features.Menu.DTOs;
using AutoMapper;
using MediatR;

namespace DashTab.Application.Features.Menu.Commands;

public record CreateProductCommand(
    Guid CategoryId,
    string Name,
    string? ShortName,
    string? Description,
    decimal Price,
    string? ImageUrl,
    string? Color,
    int SortOrder,
    int? PrepTimeMinutes
) : IRequest<Result<ProductDto>>;

public class CreateProductCommandHandler
    : IRequestHandler<CreateProductCommand, Result<ProductDto>>
{
    private readonly IApplicationDbContext _context;
    private readonly IMapper _mapper;

    public CreateProductCommandHandler(IApplicationDbContext context, IMapper mapper)
    {
        _context = context;
        _mapper = mapper;
    }

    public async Task<Result<ProductDto>> Handle(
        CreateProductCommand request, CancellationToken cancellationToken)
    {
        var product = new DashTab.Domain.Entities.Product
        {
            CategoryId = request.CategoryId,
            Name = request.Name,
            ShortName = request.ShortName,
            Description = request.Description,
            Price = request.Price,
            ImageUrl = request.ImageUrl,
            Color = request.Color,
            SortOrder = request.SortOrder,
            PrepTimeMinutes = request.PrepTimeMinutes,
            IsActive = true,
            IsAvailable = true
        };

        _context.Products.Add(product);
        await _context.SaveChangesAsync(cancellationToken);

        return Result<ProductDto>.Success(_mapper.Map<ProductDto>(product));
    }
}
