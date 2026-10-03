using System.ComponentModel.DataAnnotations;

namespace backend.Dtos
{
    /// <summary>
    /// The client supplies only the numeric SKU suffix.  The API builds and
    /// validates the complete SKU from the selected database catalogue entries.
    /// </summary>
    public class CreateInventoryItemRequest
    {
        [Range(1, int.MaxValue)]
        public int PackagingTypeId { get; set; }

        [Range(1, int.MaxValue)]
        public int RawMaterialId { get; set; }

        [Range(1, 999999)]
        public int SkuNumber { get; set; }

        [Range(0, int.MaxValue)]
        public int StockLevel { get; set; }

        [Range(0, int.MaxValue)]
        public int ReorderThreshold { get; set; }
    }
}
