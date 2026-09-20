namespace backend.Services
{
    public interface IBarcodeService
    {
        /// <summary>
        /// Generates a URL to a QR code image representing the provided data.
        /// </summary>
        /// <param name="data">The data to encode in the QR code (e.g., Roll Identifier).</param>
        /// <returns>A URL pointing to the generated QR code image.</returns>
        string GenerateQrCodeUrl(string data);
    }
}

