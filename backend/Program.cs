using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Register EF Core PostgreSQL Database Context
builder.Services.AddDbContext<ManufacturingContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Register Inventory Service Dependency Injection
builder.Services.AddScoped<IInventoryService, InventoryService>();

// Enable CORS for Flutter mobile & web clients
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Enable Swagger UI middleware so API endpoints appear in Swagger UI
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Automated Manufacturing Inventory API v1");
    c.RoutePrefix = string.Empty; // Serve Swagger UI at root URL
});

// Auto-create database tables on startup
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<ManufacturingContext>();
    dbContext.Database.EnsureCreated();
}

app.UseCors("AllowAll");
app.UseAuthorization();
app.MapControllers();

app.Run();
