using AutoMapper;
using DashTab.Application.Features.Floors.DTOs;
using DashTab.Domain.Entities;

namespace DashTab.Application.Features.Floors;

public class FloorMappingProfile : Profile
{
    public FloorMappingProfile()
    {
        CreateMap<Floor, FloorDto>();
        CreateMap<Table, TableDto>();
    }
}
