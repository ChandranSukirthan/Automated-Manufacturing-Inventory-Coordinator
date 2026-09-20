using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Models.Inventory
{
    public class InventoryRoll
    {
        public string Id { get; set; } = string.Empty;
        public string BatchId { get; set; } = string.Empty;
        public InventoryStatus Status { get; set; } = InventoryStatus.Available;

        public Batch Batch { get; set; } = null!;
    }
}