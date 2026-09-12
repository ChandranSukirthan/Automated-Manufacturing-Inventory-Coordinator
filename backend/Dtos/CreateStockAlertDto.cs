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
    }
}
