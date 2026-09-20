using System;

namespace backend.Dtos
{
    public class StockAlertResponseDto
    {
        public int Id { get; set; }
        public string Sku { get; set; } = string.Empty;
        public string PackagingType { get; set; } = string.Empty;
        public int QuantityRequested { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; }
        public string WorkerId { get; set; } = string.Empty;
    }
}
