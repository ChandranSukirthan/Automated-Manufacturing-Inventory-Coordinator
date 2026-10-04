using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using backend.Data;
using backend.Models;
using backend.Services;
using ManufacturingCoordinator.Api.Controllers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Api.Middleware;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Services.PurchaseOrders;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace backend.Tests;

// Real MVC routing, model binding, signed JWT authorization and application services.
// AI requests fail offline; email and payments are replaced at the service boundary.
public sealed class RoleCrudHttpTests : IDisposable
{
    private const string Key = "isolated-http-test-signing-key-over-32-characters";
    private readonly TestServer server;
    private readonly Guid actor = Guid.NewGuid();
    public RoleCrudHttpTests()
    {
        var database = Guid.NewGuid().ToString();
        var root = new InMemoryDatabaseRoot();
        server = new TestServer(new WebHostBuilder().ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(
            new Dictionary<string, string?> { ["AiService:BaseUrl"] = "http://127.0.0.1:1" }))
            .ConfigureServices(services =>
            {
                services.AddDbContext<ApplicationDbContext>(o => o.UseInMemoryDatabase(database, root));
                services.AddDbContext<ManufacturingContext>(o => o.UseInMemoryDatabase(database, root));
                services.AddMemoryCache(); services.AddHttpContextAccessor();
                services.AddScoped<IInventoryService, InventoryService>(); services.AddScoped<IBarcodeService, BarcodeService>();
                services.AddScoped<ISupplierService, SupplierService>(); services.AddScoped<IPurchaseOrderService, PurchaseOrderService>();
                services.AddScoped<IProcurementService, ProcurementService>(); services.AddScoped<GoodsReceiptService>();
                services.AddScoped<IDefectReportService, DefectReportService>(); services.AddScoped<IQuarantineService, QuarantineService>();
                services.AddScoped<IMachineService, MachineService>(); services.AddScoped<IMaintenanceService, MaintenanceService>();
                services.AddScoped<IShiftService, ShiftService>(); services.AddScoped<IAuditService, AuditService>();
                services.AddScoped<IAdminService, AdminService>(); services.AddScoped<IPasswordHasher, PasswordHasher>();
                services.AddSingleton<IStripeService, DummyStripeService>(); services.AddSingleton<IEmailService, DummyEmailService>();
                services.AddHttpClient().ConfigureHttpClientDefaults(b => b.ConfigurePrimaryHttpMessageHandler(() => new OfflineHandler()));
                services.AddHttpClient<IAgentIntegrationService, AgentIntegrationService>();
                services.AddControllers().AddApplicationPart(typeof(MachinesController).Assembly)
                    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
                services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o => o.TokenValidationParameters = new()
                {
                    ValidateIssuer = true, ValidIssuer = "test", ValidateAudience = true, ValidAudience = "test",
                    ValidateLifetime = true, ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Key))
                });
                services.AddAuthorization();
            }).Configure(app =>
            {
                app.UseMiddleware<ExceptionMiddleware>(); app.UseRouting(); app.UseAuthentication(); app.UseAuthorization();
                app.UseEndpoints(endpoints => endpoints.MapControllers());
            }));
        using var scope = server.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        db.PackagingTypes.Add(new PackagingType { Id = 1, Name = "BoxPouch", ShortCode = "BP" });
        db.RawMaterials.Add(new RawMaterial { Id = 1, SkuCode = "BP-FILM-001", MaterialCode = "FILM", Name = "Film", Category = "BoxPouch", PackagingTypeId = 1 });
        db.SaveChanges();
    }
    private sealed class OfflineHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => throw new HttpRequestException("AI is deliberately unavailable during manual CRUD verification");
    }
    public void Dispose() => server.Dispose();
    private HttpClient Client(string? role)
    {
        var client = server.CreateClient();
        if (role != null)
        {
            var token = new JwtSecurityToken("test", "test", new[] { new Claim(ClaimTypes.NameIdentifier, actor.ToString()),
                new Claim(ClaimTypes.Name, "Offline operator"), new Claim(ClaimTypes.Role, role) }, expires: DateTime.UtcNow.AddMinutes(10),
                signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Key)), SecurityAlgorithms.HmacSha256));
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", new JwtSecurityTokenHandler().WriteToken(token));
        }
        return client;
    }
    private static async Task<JsonElement> Success(HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.IsSuccessStatusCode, $"{response.StatusCode}: {body}");
        return string.IsNullOrEmpty(body) ? default : JsonDocument.Parse(body).RootElement.Clone();
    }

    [Theory]
    [InlineData("FloorWorker", "/api/suppliers")]
    [InlineData("QualityInspector", "/api/inventory")]
    [InlineData("SupplyChainManager", "/api/machines")]
    [InlineData("ITAdmin", "/api/suppliers")]
    public async Task Roles_CannotWriteOutsideTheirDomain(string role, string route)
    {
        using var client = Client(role);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync(route, new { })).StatusCode);
        Assert.Equal(role == "QualityInspector" ? HttpStatusCode.NotFound : HttpStatusCode.Forbidden,
            (await client.PostAsJsonAsync($"/api/quarantine/{Guid.NewGuid()}/release", new { })).StatusCode);
    }

    [Fact]
    public async Task AnonymousCrud_IsRejected()
    {
        using var client = Client(null);
        foreach (var route in new[] { "/api/inventory", "/api/defects", "/api/suppliers", "/api/machines", "/api/admin/users" })
            Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(route)).StatusCode);
    }

    [Fact]
    public async Task FloorWorker_ManualStockAndRollCrudWorksWithAiOffline()
    {
        using var client = Client("FloorWorker");
        var item = await Success(await client.PostAsJsonAsync("/api/inventory", new { packagingTypeId = 1, rawMaterialId = 1, skuNumber = 1, stockLevel = 0, reorderThreshold = 2 }));
        var itemId = item.GetProperty("id").GetInt32();
        var roll = await Success(await client.PostAsJsonAsync("/api/inventory/rolls", new { rawMaterialId = 1, batchId = "BATCH-HTTP", rollIdentifier = "HTTP-ROLL", initialQuantity = 10 }));
        var id = roll.GetProperty("id").GetInt32();
        await Success(await client.PutAsJsonAsync($"/api/inventory/rolls/{id}", new { id, initialQuantity = 10, currentQuantity = 4, status = "In Stock" }));
        var current = await Success(await client.GetAsync($"/api/inventory/{itemId}"));
        Assert.Equal(4, current.GetProperty("stockLevel").GetInt32());
        Assert.Equal(HttpStatusCode.Conflict, (await client.DeleteAsync($"/api/inventory/{itemId}")).StatusCode);
        await Success(await client.DeleteAsync($"/api/inventory/rolls/{id}"));
        await Success(await client.DeleteAsync($"/api/inventory/{itemId}"));
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/inventory/{itemId}")).StatusCode);
    }

    [Fact]
    public async Task QualityInspector_CanReadPhysicalInventoryAndCompleteDefectQuarantineRelease()
    {
        using var worker = Client("FloorWorker"); using var qa = Client("QualityInspector");
        await Success(await worker.PostAsJsonAsync("/api/inventory", new { packagingTypeId = 1, rawMaterialId = 1, skuNumber = 1 }));
        await Success(await worker.PostAsJsonAsync("/api/inventory/rolls", new { rawMaterialId = 1, batchId = "QA-BATCH", rollIdentifier = "QA-ROLL", initialQuantity = 8 }));
        await Success(await qa.GetAsync("/api/inventory/rolls"));
        await Success(await qa.GetAsync("/api/inventory/rawmaterials"));
        var defect = await Success(await qa.PostAsJsonAsync("/api/defects", new { skuCode = "BP-FILM-001", severity = "HIGH", description = "Seal defect", affectedInventory = new[] { "QA-ROLL" } }));
        var id = defect.GetProperty("id").GetString();
        Assert.Equal("QA-BATCH", defect.GetProperty("batchId").GetString());
        await Success(await qa.PutAsJsonAsync($"/api/defects/{id}", new { description = "Seal defect confirmed" }));
        var holds = await Success(await qa.PostAsJsonAsync($"/api/defects/{id}/quarantine", new { reason = "Inspect seal" }));
        var holdId = holds[0].GetProperty("id").GetString();
        Assert.Equal(HttpStatusCode.Forbidden, (await worker.PostAsJsonAsync($"/api/quarantine/{holdId}/release", new { })).StatusCode);
        await Success(await qa.PostAsJsonAsync($"/api/quarantine/{holdId}/release", new { resolutionNote = "Inspected" }));
        await Success(await qa.PostAsJsonAsync($"/api/quarantine/{holdId}/release", new { resolutionNote = "Retry" }));
        Assert.Equal(HttpStatusCode.Conflict, (await qa.DeleteAsync($"/api/defects/{id}")).StatusCode);
        var stock = await Success(await worker.GetAsync("/api/inventory"));
        Assert.Equal(8, stock[0].GetProperty("stockLevel").GetInt32());
    }

    [Fact]
    public async Task SupplyChainManager_SupplierQuoteAndDraftCrudWorksWithAiOffline()
    {
        using var client = Client("SupplyChainManager");
        var supplier = await Success(await client.PostAsJsonAsync("/api/suppliers", new { name = "Offline Supplier", contactEmail = "offline@example.test", leadTimeDays = 3 }));
        var id = supplier.GetProperty("id").GetInt32();
        await Success(await client.PutAsJsonAsync($"/api/suppliers/{id}", new { name = "Updated Supplier", contactEmail = "offline@example.test", leadTimeDays = 4, isActive = true }));
        var quoteBody = new { rawMaterialId = 1, unitPrice = 2, packSize = 1, minimumOrderQuantity = 0, availableQuantity = 100, leadTimeDays = 4, qualityEvidence = "Recorded inspection", currency = "USD", isActive = true };
        var quote = await Success(await client.PostAsJsonAsync($"/api/suppliers/{id}/quotes", quoteBody));
        var quoteId = quote.GetProperty("id").GetInt32();
        await Success(await client.PutAsJsonAsync($"/api/suppliers/{id}/quotes/{quoteId}", quoteBody));
        var po = await Success(await client.PostAsJsonAsync("/api/purchase-orders", new { supplierId = id, budgetLimit = 100, lines = new[] { new { rawMaterialId = 1, quantity = 10, unitPrice = 2 } } }));
        var poId = po.GetProperty("id").GetInt32();
        Assert.Equal("Draft", po.GetProperty("status").GetString());
        await Success(await client.PutAsJsonAsync($"/api/purchase-orders/{poId}", new { supplierId = id, budgetLimit = 100, currency = "USD", notes = "Updated draft", lines = new[] { new { rawMaterialId = 1, quantity = 12, unitPrice = 2 } } }));
        var addedLine = await Success(await client.PostAsJsonAsync($"/api/purchase-orders/{poId}/lines", new { rawMaterialId = 1, description = "Second line", quantity = 2, unitPrice = 3 }));
        var lineId = addedLine.GetProperty("id").GetInt32();
        await Success(await client.PutAsJsonAsync($"/api/purchase-orders/{poId}/lines/{lineId}", new { rawMaterialId = 1, description = "Updated line", quantity = 3, unitPrice = 3 }));
        await Success(await client.GetAsync($"/api/purchase-orders/{poId}/lines"));
        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/purchase-orders/{poId}/lines/{lineId}")).StatusCode);
        await Success(await client.GetAsync($"/api/purchase-orders/{poId}"));
        await Success(await client.DeleteAsync($"/api/purchase-orders/{poId}"));
        await Success(await client.DeleteAsync($"/api/suppliers/{id}/quotes/{quoteId}"));
        await Success(await client.DeleteAsync($"/api/suppliers/{id}"));
    }

    [Fact]
    public async Task ItAdmin_UserMachineShiftAndMaintenanceCrudWorksWithAiOffline()
    {
        using var client = Client("ITAdmin");
        var user = await Success(await client.PostAsJsonAsync("/api/admin/users", new { fullName = "Test worker", email = "worker@example.test", password = "Offline-test-123!", role = "FloorWorker" }));
        var userId = user.GetProperty("id").GetString();
        await Success(await client.GetAsync($"/api/admin/users/{userId}"));
        await Success(await client.PutAsJsonAsync($"/api/admin/users/{userId}", new { fullName = "Updated worker", email = "updated-worker@example.test" }));
        await Success(await client.PutAsJsonAsync($"/api/admin/users/{userId}/role", new { role = "QualityInspector" }));
        await Success(await client.PutAsJsonAsync($"/api/admin/users/{userId}/deactivate", new { }));
        await Success(await client.PutAsJsonAsync($"/api/admin/users/{userId}/activate", new { }));
        var machine = await Success(await client.PostAsJsonAsync("/api/machines", new { name = "Test Press", maintenanceIntervalHours = 500, location = "Isolated" }));
        var machineId = machine.GetProperty("id").GetString();
        await Success(await client.PutAsJsonAsync($"/api/machines/{machineId}", new { name = "Updated Press", maintenanceIntervalHours = 600, location = "Isolated", uptimeHours = 10 }));
        await Success(await client.GetAsync($"/api/machines/{machineId}"));
        var maintenance = await Success(await client.PostAsJsonAsync("/api/maintenance", new { machineId, description = "Test inspection", performedBy = "Technician", type = "Scheduled" }));
        var maintenanceId = maintenance.GetProperty("id").GetString();
        await Success(await client.PutAsJsonAsync($"/api/maintenance/{maintenanceId}", new { description = "Updated inspection", performedBy = "Technician", type = "Scheduled" }));
        Assert.Equal(HttpStatusCode.Conflict, (await client.DeleteAsync($"/api/machines/{machineId}")).StatusCode);
        var shift = await Success(await client.PostAsJsonAsync("/api/shifts", new { name = "Test shift", productionTarget = 100, availableMaterial = 60, startTime = DateTime.UtcNow, endTime = DateTime.UtcNow.AddHours(8) }));
        var shiftId = shift.GetProperty("id").GetString();
        var adjusted = await Success(await client.PostAsJsonAsync($"/api/shifts/{shiftId}/adjust-output", new { }));
        Assert.Equal(60, adjusted.GetProperty("adjustedOutput").GetInt32());
        await Success(await client.GetAsync("/api/admin/audit-logs"));
    }
}
