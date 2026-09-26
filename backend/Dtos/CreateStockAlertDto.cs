using System.ComponentModel.DataAnnotations;

namespace backend.Dtos
{
    public class CreateStockAlertDto
    {
        [Required]
        public string Sku { get; set; } = string.Empty;

        [Required]
        public string PackagingType { get; set; } = string.Empty;

        [Range(1, int.MaxValue, ErrorMessage = "Quantity must be at least 1.")]
        public int QuantityRequested { get; set; }

        public string WorkerId { get; set; } = string.Empty;

        // Supply Chain Manager optional inputs
        public int? MaterialId { get; set; }
        public string? MaterialName { get; set; }
        public decimal? CurrentStock { get; set; }
        public decimal? RequiredQuantity { get; set; }
        public decimal? SafetyStock { get; set; }
        public decimal? OpenPurchaseQuantity { get; set; }
        public string? Severity { get; set; }
    }
}
