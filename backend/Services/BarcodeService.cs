using System;

namespace backend.Services
{
    public class BarcodeService : IBarcodeService
    {
        // Using goqr.me API (api.qrserver.com) which is a public third-party QR code generation service
        private const string QrApiBaseUrl = "https://api.qrserver.com/v1/create-qr-code/";

        public string GenerateQrCodeUrl(string data)
        {
            if (string.IsNullOrWhiteSpace(data))
            {
                throw new ArgumentException("Data to encode cannot be null or empty", nameof(data));
            }

            // URL encode the data to ensure it's safe for a query string
            string encodedData = Uri.EscapeDataString(data);
            
            // Generate a 250x250 QR code URL
            return $"{QrApiBaseUrl}?size=250x250&data={encodedData}";
        }
    }
}

