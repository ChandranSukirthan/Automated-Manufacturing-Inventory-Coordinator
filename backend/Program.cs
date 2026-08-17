using DotNetEnv;
using ManufacturingCoordinator.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Load .env file (if exists)
Env.Load();

// Map environment variables to configuration
var dbHost = Env.GetString("DB_HOST", "localhost");
var dbPort = Env.GetString("DB_PORT", "5432");
var dbName = Env.GetString("DB_NAME", "inventory_coordinator");
var dbUser = Env.GetString("DB_USER", "postgres");
var dbPass = Env.GetString("DB_PASSWORD", "Sukir211002");
builder.Configuration["ConnectionStrings:DefaultConnection"] = $"Host={dbHost};Port={dbPort};Database={dbName};Username={dbUser};Password={dbPass}";

builder.Configuration["SendGridSettings:ApiKey"] = Env.GetString("SENDGRID_API_KEY") ?? builder.Configuration["SendGridSettings:ApiKey"];
builder.Configuration["SendGridSettings:FromEmail"] = Env.GetString("SENDGRID_FROM_EMAIL") ?? builder.Configuration["SendGridSettings:FromEmail"];
builder.Configuration["SendGridSettings:FromName"] = Env.GetString("SENDGRID_FROM_NAME") ?? builder.Configuration["SendGridSettings:FromName"];

builder.Configuration["JwtSettings:SecretKey"] = Env.GetString("JWT_SECRET_KEY") ?? builder.Configuration["JwtSettings:SecretKey"];
builder.Configuration["JwtSettings:Issuer"] = Env.GetString("JWT_ISSUER") ?? builder.Configuration["JwtSettings:Issuer"];
builder.Configuration["JwtSettings:Audience"] = Env.GetString("JWT_AUDIENCE") ?? builder.Configuration["JwtSettings:Audience"];

// Controllers
builder.Services.AddControllers();

// PostgreSQL + Entity Framework Core
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection")
    )
);

// Settings
builder.Services.Configure<JwtSettings>(builder.Configuration.GetSection("JwtSettings"));
builder.Services.Configure<SendGridSettings>(builder.Configuration.GetSection("SendGridSettings"));

// Scoped Services
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<IAuthService, AuthService>();

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

// CORS for React frontend
builder.Services.AddCors(options =>
{
    options.AddPolicy("ReactFrontend", policy =>
    {
        policy
            .WithOrigins("http://localhost:5173")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

// Swagger
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("ReactFrontend");

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();