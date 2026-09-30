using System.ComponentModel.DataAnnotations;

namespace backend.Dtos
{
    public class CreateStockAlertDto
    {
        [Required]
        public string Sku { get; set; } = string.Empty;

        [Required]
        public string PackagingType { get; set; } = string.Empty;

        // Optional structured catalogue selection. Existing clients can still
        // send an SKU, but the API always resolves it against the catalogue.
        public int? PackagingTypeId { get; set; }
        public int? RawMaterialId { get; set; }
        public int? SkuNumber { get; set; }

        [Range(1, int.MaxValue, ErrorMessage = "Quantity must be at least 1.")]
        public int QuantityRequested { get; set; }

        public string WorkerId { get; set; } = string.Empty;
    }
}
