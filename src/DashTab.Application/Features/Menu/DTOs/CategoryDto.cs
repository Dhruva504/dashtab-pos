namespace DashTab.Application.Features.Menu.DTOs;

public class CategoryDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Color { get; set; }
    public string? Icon { get; set; }
    public int SortOrder { get; set; }
    public Guid? ParentCategoryId { get; set; }
    public List<ProductDto> Products { get; set; } = new();
}
