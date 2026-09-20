using System.Collections.Generic;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Models.Inventory
{
    public class Batch
    {
        public string Id { get; set; } = string.Empty;
        public ProductType ProductType { get; set; }

        public ICollection<InventoryRoll> InventoryRolls { get; set; } = new List<InventoryRoll>();
    }
}