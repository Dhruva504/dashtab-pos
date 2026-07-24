using AutoMapper;
using DashTab.Application.Features.Menu.DTOs;
using DashTab.Domain.Entities;

namespace DashTab.Application.Features.Menu;

public class MenuMappingProfile : Profile
{
    public MenuMappingProfile()
    {
        CreateMap<Category, CategoryDto>();
        CreateMap<Product, ProductDto>();
    }
}
