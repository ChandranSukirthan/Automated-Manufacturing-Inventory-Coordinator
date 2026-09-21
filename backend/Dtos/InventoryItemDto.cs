namespace backend.Dtos
{
    public class InventoryItemDto
    {
        public int Id { get; set; }
        public string Sku { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public int StockLevel { get; set; }
        public int ReorderThreshold { get; set; }
        public bool IsLowStock => StockLevel <= ReorderThreshold;
    }
}
