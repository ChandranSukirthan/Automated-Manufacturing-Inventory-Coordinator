using System.ComponentModel.DataAnnotations;

namespace backend.Dtos
{
    /// <summary>
    /// The client can either supply the catalogue-based selection (PackagingTypeId, RawMaterialId, SkuNumber)
    /// or directly supply the SKU code, item name, and category.
    /// </summary>
    public class CreateInventoryItemRequest
    {
        // Direct creation fields (Worker Dashboard / Web)
        public string? Sku { get; set; }

        public string? Name { get; set; }

        public string? Category { get; set; }

        // Catalogue-based creation fields (Mobile / Catalogue Picker)
        public int? PackagingTypeId { get; set; }

        public int? RawMaterialId { get; set; }

        public int? SkuNumber { get; set; }

        [Range(0, int.MaxValue)]
        public int StockLevel { get; set; }

        [Range(0, int.MaxValue)]
        public int ReorderThreshold { get; set; }
    }
}
