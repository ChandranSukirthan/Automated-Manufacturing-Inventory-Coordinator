using backend.Models;
using ManufacturingCoordinator.Api.DTOs.Production;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Models.Production;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace backend.Tests;

public class ProductionContextTests
{
    [Fact]
    public async Task AssociatedShiftUsesMaterialConversionAndPreservesLegacyCapacity()
    {
        await using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var machine = new Machine { Name = "Machine A" };
        db.Machines.Add(machine);
        db.RawMaterials.Add(new RawMaterial { SkuCode = "RM001", Name = "Film", MaterialCode = "FILM", Category = "BoxPouch" });
        await db.SaveChangesAsync();
        var service = new ShiftService(db);
        var start = DateTime.UtcNow;
        var result = await service.CreateAsync(new CreateShiftDto { Name = "Converted shift", ProductionTarget = 10000, AvailableMaterial = 6000,
            MaterialSku = "RM001", MachineId = machine.Id, MaterialPerUnit = 2, StartTime = start, EndTime = start.AddHours(8) });
        Assert.Equal(3000, result.AdjustedOutput);
        Assert.Equal(machine.Id, result.MachineId);
        var legacy = await service.CreateAsync(new CreateShiftDto { Name = "Legacy capacity", ProductionTarget = 10000, AvailableMaterial = 6000, StartTime = start, EndTime = start.AddHours(8) });
        Assert.Equal(6000, legacy.AdjustedOutput);
        await Assert.ThrowsAsync<ManufacturingCoordinator.Api.Helpers.AuthException>(() => service.CreateAsync(new CreateShiftDto { Name = "Invalid", ProductionTarget = 1, MaterialSku = "MISSING", MaterialPerUnit = 1, StartTime = start, EndTime = start.AddHours(8) }));
    }
}
