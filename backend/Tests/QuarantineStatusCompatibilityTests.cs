using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using Microsoft.EntityFrameworkCore;
using Xunit;
using QualityRoll = ManufacturingCoordinator.Models.Inventory.InventoryRoll;

namespace backend.Tests;

public class QuarantineStatusCompatibilityTests
{
    [Theory]
    [InlineData("Available", InventoryStatus.Available)]
    [InlineData("In Stock", InventoryStatus.Available)]
    [InlineData("Quarantined", InventoryStatus.Quarantined)]
    [InlineData("On Hold", InventoryStatus.Quarantined)]
    [InlineData("Locked", InventoryStatus.Quarantined)]
    [InlineData("Unexpected", InventoryStatus.Quarantined)]
    public void ReadsHistoricalStatusesWithoutUnlockingHeldInventory(string stored, InventoryStatus expected)
    {
        using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var converter = db.Model.FindEntityType(typeof(QualityRoll))!
            .FindProperty(nameof(QualityRoll.Status))!.GetTypeMapping().Converter!;

        Assert.Equal(expected, converter.ConvertFromProvider(stored));
        Assert.Equal("In Stock", converter.ConvertToProvider(InventoryStatus.Available));
        Assert.Equal("Quarantined", converter.ConvertToProvider(InventoryStatus.Quarantined));
    }
}
