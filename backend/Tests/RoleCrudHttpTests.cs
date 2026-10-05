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
            new Dictionary<string, string?> { ["AiService:BaseUrl"] = "http://127.0.0.1:1", ["JwtSettings:SecretKey"] = Key }))
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
    [Fact]
    public async Task BoundedSupplierListRejectsInvalidPagingAndFiltersBeforePaging()
    {
        using var client = Client("SupplyChainManager");
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/suppliers/paged?pageSize=101")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/suppliers/paged?sort=arbitrary_sql")).StatusCode);
        var response = await client.GetAsync("/api/suppliers/paged?page=1&pageSize=5&search=missing");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(0, body.GetProperty("totalCount").GetInt32());
        Assert.Equal(5, body.GetProperty("pageSize").GetInt32());
    }

    [Fact]
    public async Task WorkflowPublicationRequiresTrustedSignatureAndCannotMutateInventory()
    {
        using var client = Client("FloorWorker");
        var state = "{\"workflow_id\":\"WF-SIGNED\",\"objective\":\"Replenish\",\"status\":\"Running\"}";
        var body = new StringContent("{\"state\":" + state + "}", Encoding.UTF8, "application/json");
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PutAsync("/api/internal/workflows/WF-SIGNED/state", body)).StatusCode);
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
        var signature = System.Security.Cryptography.HMACSHA256.HashData(Encoding.UTF8.GetBytes(Key), Encoding.UTF8.GetBytes(timestamp + "\n" + state));
        client.DefaultRequestHeaders.Add("X-AI-Timestamp", timestamp);
        client.DefaultRequestHeaders.Add("X-AI-Signature", Convert.ToHexString(signature));
        var signed = await client.PutAsync("/api/internal/workflows/WF-SIGNED/state", new StringContent("{\"state\":" + state + "}", Encoding.UTF8, "application/json"));
        Assert.Equal(HttpStatusCode.OK, signed.StatusCode);
        using var scope = server.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Single(await db.AgentWorkflows.ToListAsync());
        Assert.Empty(await db.PurchaseOrders.ToListAsync());
        Assert.Empty(await db.InventoryItems.ToListAsync());
    }

    [Fact]
    public async Task LocalPagedApiPerformanceEvidence()
    {
        using var client = Client("SupplyChainManager");
        using (var scope = server.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.Suppliers.AddRange(Enumerable.Range(1, 1000).Select(i => new ManufacturingCoordinator.Models.PurchaseOrders.Supplier { Name = $"Supplier {i:D4}", SupplierCode = $"SUP-{i:D4}" }));
            await db.SaveChangesAsync();
        }
        for (var i = 0; i < 5; i++) await Success(await client.GetAsync("/api/suppliers/paged?pageSize=20"));
        var samples = new List<double>();
        for (var i = 0; i < 50; i++)
        {
            var watch = System.Diagnostics.Stopwatch.StartNew();
            var result = await Success(await client.GetAsync($"/api/suppliers/paged?pageSize=20&page={i % 10 + 1}"));
            watch.Stop(); samples.Add(watch.Elapsed.TotalMilliseconds);
            Assert.Equal(20, result.GetProperty("items").GetArrayLength());
            Assert.Equal(1000, result.GetProperty("totalCount").GetInt32());
        }
        samples.Sort();
        var report = new { environment = "Local ASP.NET TestServer, EF InMemory, 1000 suppliers; no network or PostgreSQL latency", requests = 50, meanMs = samples.Average(), p95Ms = samples[47], maxMs = samples[^1], measuredAt = DateTime.UtcNow };
        var output = Path.Combine("TestResults", "performance.json");
        Directory.CreateDirectory("TestResults");
        await File.WriteAllTextAsync(output, JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));
        Assert.True(report.p95Ms < 2000, "Local paged API regression exceeded two seconds.");
    }

    public void Dispose() => server.Dispose();
    private HttpClient Client(string? role)
    {
        var client = server.CreateClient();
        if (role != null)
        {
            var token = new JwtSecurityToken("test", "test", new[] { new Claim(ClaimTypes.NameIdentifier, actor.ToString()),
                new Claim(ClaimTypes.Name, "Offline operator"), new Claim("employee_id", "EMP-HTTP-TEST"), new Claim(ClaimTypes.Role, role) }, expires: DateTime.UtcNow.AddMinutes(10),
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
    public async Task QualityWorkflowHistoryIncludesProductQuantityAndValidationExecution()
    {
        using var client = Client("QualityInspector");
        using (var scope = server.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.AgentWorkflows.Add(new ManufacturingCoordinator.Models.Administration.AgentWorkflow {
                WorkflowId = "WF-QA-CONTEXT", Objective = "Replenish film",
                ValidationResults = "{\"isValid\":true,\"supplierValidation\":\"PASSED\",\"qualitySafetyStatus\":\"CLEAR\"}",
                StateJson = "{\"material_id\":\"BP-FILM-001\",\"material_name\":\"Film\",\"required_quantity\":2000,\"unit\":\"KG\",\"draft_po\":{\"quantity\":2100}}"
            });
            db.AgentWorkflows.Add(new ManufacturingCoordinator.Models.Administration.AgentWorkflow {
                WorkflowId = "WF-NO-SUPPLIER", Objective = "Replenish ink",
                ValidationResults = "{\"isValid\":false,\"overallStatus\":\"NO_VALID_SUPPLIER\"}",
                StateJson = "{\"material_id\":\"BP-INK-001\",\"required_quantity\":100}"
            });
            await db.SaveChangesAsync();
        }
        var history = await Success(await client.GetAsync("/api/quality/ai-validation/history"));
        var checkedWorkflow = history.EnumerateArray().Single(w => w.GetProperty("workflowId").GetString() == "WF-QA-CONTEXT");
        Assert.Equal("BP-FILM-001", checkedWorkflow.GetProperty("materialId").GetString());
        Assert.Equal("Film", checkedWorkflow.GetProperty("materialName").GetString());
        Assert.Equal(2100, checkedWorkflow.GetProperty("quantity").GetDecimal());
        Assert.True(checkedWorkflow.GetProperty("validationExecuted").GetBoolean());
        var blocked = history.EnumerateArray().Single(w => w.GetProperty("workflowId").GetString() == "WF-NO-SUPPLIER");
        Assert.False(blocked.GetProperty("validationExecuted").GetBoolean());
        var selected = await Success(await client.GetAsync("/api/quality/ai-validation?workflowId=WF-QA-CONTEXT"));
        Assert.Equal("WF-QA-CONTEXT", selected.GetProperty("workflowId").GetString());
    }

    [Fact]
    public async Task FloorWorker_AlertsUseMaterialIdentityAndRejectInvalidStatus()
    {
        using var client = Client("FloorWorker");
        using (var scope = server.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ManufacturingContext>();
            db.InventoryItems.Add(new InventoryItem { Id = 91, RawMaterialId = 1, Sku = "BP-FILM-001", Name = "Film", StockLevel = 10 });
            await db.SaveChangesAsync();
        }
        var alert = await Success(await client.PostAsJsonAsync("/api/inventory/alerts", new { sku = "BP-FILM-001", quantityRequested = 100, materialId = 999 }));
        var id = alert.GetProperty("id").GetInt32();
        Assert.Equal(1, alert.GetProperty("materialId").GetInt32());
        var duplicate = await Success(await client.PostAsJsonAsync("/api/inventory/alerts", new { sku = "BP-FILM-001", quantityRequested = 100 }));
        Assert.Equal(id, duplicate.GetProperty("id").GetInt32());
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PutAsJsonAsync($"/api/inventory/alerts/{id}", new { status = "INVALID" })).StatusCode);
        await Success(await client.PutAsJsonAsync($"/api/inventory/alerts/{id}", new { status = "Acknowledged" }));
        var alerts = await Success(await client.GetAsync("/api/inventory/alerts"));
        Assert.Equal("Acknowledged", alerts[0].GetProperty("status").GetString());
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
