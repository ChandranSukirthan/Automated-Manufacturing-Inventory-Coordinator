using DotNetEnv;
using ManufacturingCoordinator.Data;
using backend.Data;
using backend.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Api.Middleware;
using ManufacturingCoordinator.Services.PurchaseOrders;

var builder = WebApplication.CreateBuilder(args);

// Load .env file (if exists)
Env.Load();

// Map environment variables to configuration
var dbHost = Env.GetString("DB_HOST", "localhost");
var dbPort = Env.GetString("DB_PORT", "5432");
var dbName = Env.GetString("DB_NAME", "inventory_coordinator");
var dbUser = Env.GetString("DB_USER", "postgres");
var dbPass = Env.GetString("DB_PASSWORD", "Sukir@211002");
builder.Configuration["ConnectionStrings:DefaultConnection"] = $"Host={dbHost};Port={dbPort};Database={dbName};Username={dbUser};Password={dbPass}";

builder.Configuration["EmailSettings:EmailUser"] = Env.GetString("EMAIL_USER") ?? builder.Configuration["EmailSettings:EmailUser"];
builder.Configuration["EmailSettings:EmailPass"] = Env.GetString("EMAIL_PASS") ?? builder.Configuration["EmailSettings:EmailPass"];

builder.Configuration["JwtSettings:SecretKey"] = Env.GetString("JWT_SECRET_KEY") ?? builder.Configuration["JwtSettings:SecretKey"];
builder.Configuration["JwtSettings:Issuer"] = Env.GetString("JWT_ISSUER") ?? builder.Configuration["JwtSettings:Issuer"];
builder.Configuration["JwtSettings:Audience"] = Env.GetString("JWT_AUDIENCE") ?? builder.Configuration["JwtSettings:Audience"];

// Controllers
builder.Services.AddControllers();

// PostgreSQL + Entity Framework Core Contexts
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"))
);

builder.Services.AddDbContext<ManufacturingContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"))
);

// Register Inventory & Agent Services
builder.Services.AddScoped<IInventoryService, InventoryService>();
builder.Services.AddScoped<IBarcodeService, BarcodeService>();
builder.Services.AddHttpClient<IAgentIntegrationService, AgentIntegrationService>();

// Register Auth Services
builder.Services.Configure<JwtSettings>(builder.Configuration.GetSection("JwtSettings"));
builder.Services.Configure<EmailSettings>(builder.Configuration.GetSection("EmailSettings"));
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<IAuthService, AuthService>();

// Register Student 2 - Purchase Order Services
builder.Services.AddScoped<ISupplierService, SupplierService>();
builder.Services.AddScoped<IStripeService, StripeService>();
builder.Services.AddScoped<IPurchaseOrderService, PurchaseOrderService>();

// Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["JwtSettings:Issuer"],
            ValidAudience = builder.Configuration["JwtSettings:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["JwtSettings:SecretKey"]!))
        };
    });

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new global::Microsoft.OpenApi.Models.OpenApiInfo { Title = "ManufacturingCoordinator API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new global::Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        In = global::Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Please enter JWT token",
        Name = "Authorization",
        Type = global::Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        BearerFormat = "JWT",
        Scheme = "bearer"
    });
    c.AddSecurityRequirement(new global::Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new global::Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new global::Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = global::Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// CORS for React frontend & Flutter mobile clients
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy
            .SetIsOriginAllowed(_ => true)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});

var app = builder.Build();

// Swagger UI
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Automated Manufacturing Inventory API v1");
    });
}

// Auto-create database tables on startup
using (var scope = app.Services.CreateScope())
{
    try
    {
        var mfgContext = scope.ServiceProvider.GetRequiredService<ManufacturingContext>();
        mfgContext.Database.EnsureCreated();

        var appContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        appContext.Database.EnsureCreated();
        DbInitializer.SeedAsync(appContext).GetAwaiter().GetResult();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"DB Auto-creation notice: {ex.Message}");
    }
}

app.UseMiddleware<ExceptionMiddleware>();

app.UseCors("AllowAll");

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
