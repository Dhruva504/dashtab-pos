using DashTab.Api.Middleware;
using DashTab.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", builder =>
        builder.AllowAnyOrigin()
               .AllowAnyMethod()
               .AllowAnyHeader());
});

// Register Infrastructure
builder.Services.AddDbContext<DashTabDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddScoped<DashTab.Application.Common.Interfaces.IApplicationDbContext>(provider => provider.GetRequiredService<DashTabDbContext>());
builder.Services.AddScoped<DashTab.Domain.Interfaces.ITenantContext, DashTab.Infrastructure.MultiTenancy.TenantContext>();
builder.Services.AddScoped<DashTab.Application.Common.Interfaces.IDateTimeProvider, DashTab.Infrastructure.Services.DateTimeProvider>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll");

// Use Tenant Middleware before auth/controllers
app.UseTenantMiddleware();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
