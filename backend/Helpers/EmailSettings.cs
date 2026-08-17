namespace ManufacturingCoordinator.Api.Helpers
{
    public class EmailSettings
    {
        public string SmtpHost { get; set; } = "smtp.gmail.com";
        public int SmtpPort { get; set; } = 587;
        public string EmailUser { get; set; } = string.Empty;
        public string EmailPass { get; set; } = string.Empty;
        public string FromName { get; set; } = "Manufacturing Inventory Coordinator";
    }
}