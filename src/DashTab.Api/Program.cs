using System.Text;
using DashTab.Api.Middleware;
using DashTab.Application.Common.Interfaces;
using DashTab.Infrastructure.Data;
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
        Description = "Supabase JWT Authorization header. Enter: Bearer {token}",
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
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
{
    options.AddPolicy("DashTabCors", policy =>
    {
        if (allowedOrigins.Length > 0)
        {
            policy.WithOrigins(allowedOrigins)
                  .AllowAnyMethod()
                  .AllowAnyHeader()
                  .AllowCredentials();
        }
        else
        {
            // Fallback for development: allow all
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
    });
});

// ─── Database (schema is owned by supabase/migrations; the API is read/report-only) ──
builder.Services.AddDbContext<DashTabDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        npgsql => npgsql.EnableRetryOnFailure(3)
    ));
builder.Services.AddScoped<IApplicationDbContext>(p => p.GetRequiredService<DashTabDbContext>());

// ─── Infrastructure Services ──────────────────────────────────────────────────
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IDateTimeProvider, DateTimeProvider>();
builder.Services.AddScoped<DashTab.Application.Common.Interfaces.ICurrentUserService, DashTab.Api.Services.CurrentUserService>();

// ─── Business Services ────────────────────────────────────────────────────────
builder.Services.AddScoped<DashTab.Application.Services.IReportService, DashTab.Application.Services.ReportService>();
builder.Services.AddScoped<DashTab.Application.Services.IAnalyticsService, DashTab.Application.Services.AnalyticsService>();
builder.Services.AddScoped<DashTab.Application.Services.IInvoiceService, DashTab.Application.Services.InvoiceService>();
builder.Services.AddScoped<DashTab.Application.Services.ITaxService, DashTab.Application.Services.TaxService>();
builder.Services.AddScoped<DashTab.Application.Services.INotificationService, DashTab.Application.Services.NotificationService>();
builder.Services.AddScoped<DashTab.Application.Services.IIntegrationService, DashTab.Application.Services.IntegrationService>();
builder.Services.AddScoped<DashTab.Application.Services.IForecastService, DashTab.Application.Services.ForecastService>();

// ─── Supabase JWT Bearer Authentication ──────────────────────────────────────
var supabaseSettings = builder.Configuration.GetSection("Supabase");
var supabaseJwtSecret = supabaseSettings["JwtSecret"]
    ?? throw new InvalidOperationException("Supabase:JwtSecret must be configured.");

// Supabase JWT uses HS256 with the JWT secret from the Supabase dashboard.
// The JWT contains claims: sub (user id), role, aud (authenticated), exp, iat, etc.
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = false,          // Supabase doesn't set a standard issuer
        ValidateAudience = false,        // Supabase uses 'aud' claim but not as OAuth audience
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(supabaseJwtSecret)),
        ClockSkew = TimeSpan.FromSeconds(30)
    };
});

builder.Services.AddAuthorization();

// ─────────────────────────────────────────────────────────────────────────────
var app = builder.Build();

// ─── Pipeline ─────────────────────────────────────────────────────────────────
app.UseGlobalExceptionMiddleware();

// Swagger available in all environments (useful for testing deployed API)
app.UseSwagger();
app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "DashTab POS API v1"));

app.UseHttpsRedirection();
app.UseCors("DashTabCors");

app.UseAuthentication();
app.UseAuthorization();

// Health-check endpoint (Render uses this to confirm the service is up)
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
   .AllowAnonymous();

app.MapControllers();

app.Run();
