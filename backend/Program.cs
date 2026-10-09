using DotNetEnv;
using ManufacturingCoordinator.Data;
using backend.Data;
using backend.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using System.Text;
using System.Text.Json.Serialization;

using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Api.Middleware;
using ManufacturingCoordinator.Services.PurchaseOrders;

var builder = WebApplication.CreateBuilder(args);

// The development API is used from the Android emulator.  Keep diagnostics on
// the console instead of relying on the Windows Event Log, which may not be
// available on a student development machine and must never abort a response.
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

// Load .env defaults without overriding values supplied by the host environment.
Env.NoClobber().Load();

// Let appsettings.json provide the default connection and use .env values only
// when they are explicitly supplied. Previously, absent .env values silently
// replaced the configured credentials with hard-coded defaults.
var configuredConnection = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is not configured.");
var connection = new NpgsqlConnectionStringBuilder(configuredConnection);

var dbHost = Env.GetString("DB_HOST");
var dbPort = Env.GetString("DB_PORT");
var dbName = Env.GetString("DB_NAME");
var dbUser = Env.GetString("DB_USER");
var dbPass = Env.GetString("DB_PASSWORD");

if (!string.IsNullOrWhiteSpace(dbHost)) connection.Host = dbHost;
if (int.TryParse(dbPort, out var parsedDbPort)) connection.Port = parsedDbPort;
if (!string.IsNullOrWhiteSpace(dbName)) connection.Database = dbName;
if (!string.IsNullOrWhiteSpace(dbUser)) connection.Username = dbUser;
if (!string.IsNullOrWhiteSpace(dbPass)) connection.Password = dbPass;

builder.Configuration["ConnectionStrings:DefaultConnection"] = connection.ConnectionString;

builder.Configuration["EmailSettings:EmailUser"] = Env.GetString("EMAIL_USER") ?? builder.Configuration["EmailSettings:EmailUser"];
builder.Configuration["EmailSettings:EmailPass"] = Env.GetString("EMAIL_PASS") ?? builder.Configuration["EmailSettings:EmailPass"];

builder.Configuration["JwtSettings:SecretKey"] = Env.GetString("JWT_SECRET_KEY") ?? builder.Configuration["JwtSettings:SecretKey"];
builder.Configuration["JwtSettings:Issuer"] = Env.GetString("JWT_ISSUER") ?? builder.Configuration["JwtSettings:Issuer"];
builder.Configuration["StripeSettings:SecretKey"] = Env.GetString("STRIPE_SECRET_KEY") ?? builder.Configuration["StripeSettings:SecretKey"];

// Resolve AgentServer (FastAPI) BaseUrl from deployment environment or .env
var configuredAgentUrl = Env.GetString("AGENT_SERVER_URL")
    ?? Env.GetString("AGENT_BASE_URL")
    ?? Env.GetString("AI_BASE_URL")
    ?? Env.GetString("AgentServer__BaseUrl")
    ?? Environment.GetEnvironmentVariable("AGENT_SERVER_URL")
    ?? Environment.GetEnvironmentVariable("AGENT_BASE_URL")
    ?? Environment.GetEnvironmentVariable("AI_BASE_URL")
    ?? Environment.GetEnvironmentVariable("AgentServer__BaseUrl");

if (!string.IsNullOrWhiteSpace(configuredAgentUrl))
{
    builder.Configuration["AgentServer:BaseUrl"] = configuredAgentUrl.TrimEnd('/');
}

// Controllers with JSON String Enum conversion
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    });

// PostgreSQL + Entity Framework Core Contexts
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"))
);

builder.Services.AddDbContext<ManufacturingContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"))
);

builder.Services.AddMemoryCache();

// Register Inventory & Agent Services (Student 1)
builder.Services.AddScoped<IInventoryService, InventoryService>();
builder.Services.AddScoped<IBarcodeService, BarcodeService>();
builder.Services.AddHttpClient<IAgentIntegrationService, AgentIntegrationService>();

// Register Auth Services (Student 1)
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
builder.Services.AddScoped<IProcurementService, ProcurementService>();
builder.Services.AddScoped<GoodsReceiptService>();
builder.Services.AddScoped<WorkflowDraftService>();
builder.Services.AddHostedService<WorkflowDraftWorker>();

// Register Student 3 - Quality & Defect Services
builder.Services.AddScoped<IDefectReportService, DefectReportService>();
builder.Services.AddScoped<IQuarantineService, QuarantineService>();

// Register Student 4 - Production & Admin Services
builder.Services.AddScoped<IMachineService, MachineService>();
builder.Services.AddScoped<IMaintenanceService, MaintenanceService>();
builder.Services.AddScoped<IShiftService, ShiftService>();
builder.Services.AddScoped<IAuditService, AuditService>();
builder.Services.AddScoped<IAdminService, AdminService>();

// HttpContextAccessor (for audit log IP capture)
builder.Services.AddHttpContextAccessor();

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

// CORS for React frontend & mobile clients
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
    options.AddPolicy("ReactFrontend", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

// Swagger UI
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Automated Manufacturing Inventory API v1");
    c.RoutePrefix = "swagger";
});

// Schema updates and demo seeding are explicit deployment choices.
if (builder.Configuration.GetValue<bool>("Database:ApplyMigrationsOnStartup"))
using (var scope = app.Services.CreateScope())
{
    try
    {
        var appContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        // The application migrations own the shared schema. Do this before
        // seeding so the Floor Worker delivery screen has its purchase-order
        // tables on both fresh and existing development databases.
        await appContext.Database.MigrateAsync();
        await appContext.Database.ExecuteSqlRawAsync(@"
            ALTER TABLE ""Users"" ADD COLUMN IF NOT EXISTS ""EmployeeId"" character varying(16);
            CREATE UNIQUE INDEX IF NOT EXISTS ""IX_Users_EmployeeId""
                ON ""Users"" (""EmployeeId"")
                WHERE ""EmployeeId"" IS NOT NULL;
        ");

        var mfgContext = scope.ServiceProvider.GetService<ManufacturingContext>();
        if (mfgContext != null && builder.Configuration.GetValue<bool>("Database:SeedDemoData"))
        {
            await StudentAInventorySeeder.SeedAsync(mfgContext);
        }

        if (builder.Configuration.GetValue<bool>("Database:SeedDemoData")) await DbInitializer.SeedAsync(app.Services);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"DB Auto-creation/seed notice: {ex.Message}");
    }
}

app.UseMiddleware<ExceptionMiddleware>();

app.UseCors("AllowAll");
app.UseStaticFiles();

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => Results.Ok(new
{
    status = "online",
    service = "Automated Manufacturing Inventory Coordinator API",
    version = "v1",
    docs = "/swagger"
}));

app.MapControllers();

app.Run();
