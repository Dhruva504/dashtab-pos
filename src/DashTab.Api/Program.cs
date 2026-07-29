using System.Text;
using DashTab.Api.Middleware;
using DashTab.Application.Common.Interfaces;
using DashTab.Domain.Common;
using DashTab.Domain.Interfaces;
using DashTab.Infrastructure.Data;
using DashTab.Infrastructure.Data.Repositories;
using DashTab.Infrastructure.MultiTenancy;
using DashTab.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// ─── MVC / API ────────────────────────────────────────────────────────────────
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// ─── Swagger (with JWT support) ───────────────────────────────────────────────
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "DashTab POS API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header. Enter: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
            Array.Empty<string>()
        }
    });
});

// ─── CORS ─────────────────────────────────────────────────────────────────────
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader());
});

// ─── Database ─────────────────────────────────────────────────────────────────
builder.Services.AddDbContext<DashTabDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        npgsql => npgsql.EnableRetryOnFailure(3)
    ));
builder.Services.AddScoped<IApplicationDbContext>(p => p.GetRequiredService<DashTabDbContext>());

// ─── Multi-Tenancy ────────────────────────────────────────────────────────────
builder.Services.AddScoped<ITenantContext, TenantContext>();

// ─── Infrastructure Services ──────────────────────────────────────────────────
builder.Services.AddScoped<IDateTimeProvider, DateTimeProvider>();
builder.Services.AddScoped<ITokenService, JwtTokenService>();

// Generic repository — IRepository<T> → Repository<T> for any T : BaseEntity
builder.Services.AddScoped(typeof(IRepository<>), typeof(Repository<>));

// ─── MediatR (scans DashTab.Application assembly) ────────────────────────────
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(typeof(DashTab.Application.Features.Auth.Commands.LoginCommand).Assembly));

// ─── AutoMapper (scans DashTab.Application assembly) ─────────────────────────
builder.Services.AddAutoMapper(typeof(DashTab.Application.Features.Menu.MenuMappingProfile).Assembly);

// ─── JWT Bearer Authentication ────────────────────────────────────────────────
var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secret = jwtSettings["Secret"]
    ?? throw new InvalidOperationException("JwtSettings:Secret must be configured.");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["Issuer"],
        ValidAudience = jwtSettings["Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddAuthorization();

// ─────────────────────────────────────────────────────────────────────────────
var app = builder.Build();

// Seed / migrate database on startup
await DatabaseSeeder.SeedAsync(app.Services);

// ─── Pipeline ─────────────────────────────────────────────────────────────────
app.UseGlobalExceptionMiddleware();

// Swagger available in all environments (useful for testing deployed API)
app.UseSwagger();
app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "DashTab POS API v1"));

app.UseHttpsRedirection();
app.UseCors("AllowAll");

// Tenant middleware must run before auth so tenant is set from header
app.UseTenantMiddleware();

app.UseAuthentication();
app.UseAuthorization();

// Health-check endpoint (Render uses this to confirm the service is up)
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
   .AllowAnonymous();

app.MapControllers();

app.Run();
