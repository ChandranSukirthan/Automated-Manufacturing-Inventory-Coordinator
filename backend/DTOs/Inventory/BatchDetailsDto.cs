using System.Collections.Generic;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Inventory
{
    public class BatchDetailsDto
    {
        public string Id { get; set; } = string.Empty;
        public ProductType ProductType { get; set; }
        public List<InventoryRollDto> InventoryRolls { get; set; } = new();
    }

    public class InventoryRollDto
    {
        public string Id { get; set; } = string.Empty;
        public string BatchId { get; set; } = string.Empty;
        public InventoryStatus Status { get; set; }
    }
}