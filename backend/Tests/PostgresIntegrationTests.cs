using backend.Models;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Services.PurchaseOrders;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Xunit;

namespace backend.Tests;

public sealed class PostgresFactAttribute : FactAttribute
{
    public PostgresFactAttribute()
    {
        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("AMIC_TEST_POSTGRES")))
            Skip = "Set AMIC_TEST_POSTGRES to a disposable PostgreSQL cluster to run relational checks.";
    }
}

public class PostgresIntegrationTests
{
    private sealed class IsolatedDatabase : IAsyncDisposable
    {
        public string Connection { get; }
        private readonly string admin;
        private readonly string name = "amic_integration_" + Guid.NewGuid().ToString("N");
        private IsolatedDatabase(string admin)
        {
            this.admin = admin;
            var builder = new NpgsqlConnectionStringBuilder(admin) { Database = name };
            Connection = builder.ConnectionString;
        }
        public static async Task<IsolatedDatabase> Create()
        {
            var database = new IsolatedDatabase(Environment.GetEnvironmentVariable("AMIC_TEST_POSTGRES")!);
            await using var conn = new NpgsqlConnection(database.admin);
            await conn.OpenAsync();
            await using var command = new NpgsqlCommand($"CREATE DATABASE {database.name}", conn);
            await command.ExecuteNonQueryAsync();
            return database;
        }
        public ApplicationDbContext Context() => new(new DbContextOptionsBuilder<ApplicationDbContext>().UseNpgsql(Connection).Options);
        public async ValueTask DisposeAsync()
        {
            NpgsqlConnection.ClearAllPools();
            await using var conn = new NpgsqlConnection(admin);
            await conn.OpenAsync();
            await using var command = new NpgsqlCommand($"DROP DATABASE {name} WITH (FORCE)", conn);
            await command.ExecuteNonQueryAsync();
        }
    }

    [PostgresFact]
    public async Task FreshMigrations_MatchEveryMappedColumnAndRetainExistingRecords()
    {
        await using var database = await IsolatedDatabase.Create();
        await using var db = database.Context();
        await db.Database.MigrateAsync();
        await using var conn = new NpgsqlConnection(database.Connection);
        await conn.OpenAsync();
        foreach (var entity in db.Model.GetEntityTypes())
        {
            var table = entity.GetTableName()!;
            var identifier = Microsoft.EntityFrameworkCore.Metadata.StoreObjectIdentifier.Table(table, entity.GetSchema());
            var columns = entity.GetProperties().Select(p => p.GetColumnName(identifier)).Distinct();
            var sql = $"SELECT {string.Join(",", columns.Select(c => "\"" + c + "\""))} FROM \"{table}\" WHERE false";
            await using var command = new NpgsqlCommand(sql, conn);
            await command.ExecuteNonQueryAsync();
        }
        db.Machines.Add(new ManufacturingCoordinator.Models.Production.Machine { Name = "Historical machine" });
        await db.SaveChangesAsync();
        await db.Database.MigrateAsync();
        Assert.Equal("Historical machine", (await db.Machines.SingleAsync()).Name);
    }

    private static async Task Seed(ApplicationDbContext db)
    {
        await db.Database.EnsureCreatedAsync();
        db.PackagingTypes.Add(new PackagingType { Id = 1, Name = "BoxPouch", ShortCode = "BP" });
        db.RawMaterials.Add(new RawMaterial { Id = 1, Name = "Film", SkuCode = "FILM-1", Category = "BoxPouch", PackagingTypeId = 1 });
        db.InventoryItems.Add(new InventoryItem { Sku = "FILM-1", StockLevel = 0 });
        db.Suppliers.Add(new Supplier { Id = 1, Name = "Test vendor", SupplierCode = "TEST-1", IsActive = true });
        var po = new PurchaseOrder { Id = 1, SupplierId = 1, PoNumber = "ISOLATED-1", Status = PurchaseOrderStatus.Sent };
        po.OrderLines.Add(new OrderLine { Id = 1, RawMaterialId = 1, Quantity = 100, UnitPrice = 2, TotalPrice = 200 });
        db.PurchaseOrders.Add(po);
        await db.SaveChangesAsync();
    }

    private static ReceiveGoodsRequest Receipt(string key, int quantity = 30) => new()
    { ReceiptKey = key, RollIdentifier = key, BatchId = "isolated-batch", OrderLineId = 1, Quantity = quantity };

    private static bool IsRetryable(Exception error) => error is PostgresException p && p.SqlState is "23505" or "40001" or "40P01"
        || error.InnerException != null && IsRetryable(error.InnerException);

    [PostgresFact]
    public async Task ConcurrentDuplicateReceipt_CountsStockExactlyOnceAndRetryReturnsReceipt()
    {
        await using var database = await IsolatedDatabase.Create();
        await using (var seed = database.Context()) await Seed(seed);
        async Task Attempt()
        {
            await using var db = database.Context();
            try { await new GoodsReceiptService(db).ReceiveAsync(1, Receipt("duplicate"), null); }
            catch (Exception ex) when (IsRetryable(ex)) { }
        }
        await Task.WhenAll(Attempt(), Attempt());
        await using var verify = database.Context();
        await new GoodsReceiptService(verify).ReceiveAsync(1, Receipt("duplicate"), null);
        Assert.Equal(30, (await verify.InventoryItems.SingleAsync()).StockLevel);
        Assert.Single(await verify.GoodsReceipts.ToListAsync());
        Assert.Single(await verify.InventoryMovements.ToListAsync());
    }

    [PostgresFact]
    public async Task ConcurrentDifferentReceipts_RetryCannotLoseStockOrExceedTheOrder()
    {
        await using var database = await IsolatedDatabase.Create();
        await using (var seed = database.Context()) await Seed(seed);
        async Task Attempt(string key)
        {
            for (var i = 0; i < 5; i++)
            {
                await using var db = database.Context();
                try { await new GoodsReceiptService(db).ReceiveAsync(1, Receipt(key), null); return; }
                catch (Exception ex) when (IsRetryable(ex)) { }
            }
            throw new Exception("Concurrent receipt did not recover after retries");
        }
        await Task.WhenAll(Attempt("delivery-a"), Attempt("delivery-b"));
        await using var verify = database.Context();
        Assert.Equal(60, (await verify.InventoryItems.SingleAsync()).StockLevel);
        Assert.Equal(2, await verify.GoodsReceipts.CountAsync());
        await Assert.ThrowsAsync<InvalidOperationException>(() => new GoodsReceiptService(verify).ReceiveAsync(1, Receipt("over-delivery", 50), null));
        Assert.Equal(60, (await verify.InventoryItems.SingleAsync()).StockLevel);
    }
}
