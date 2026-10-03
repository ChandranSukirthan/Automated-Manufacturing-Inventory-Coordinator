using System;
using System.Threading;
using System.Threading.Tasks;

namespace backend.Services
{
    public interface IBarcodeService
    {
        /// <summary>
        /// Requests a PNG QR code for a validated inventory-roll identifier.
        /// The caller receives image bytes - never a third-party URL.
        /// </summary>
        Task<QrCodeImage> GenerateInventoryRollQrAsync(
            string rollIdentifier,
            CancellationToken cancellationToken = default);
    }

    public sealed record QrCodeImage(byte[] Bytes, string ContentType);

    public sealed class QrCodeProviderException : Exception
    {
        public QrCodeProviderException(string message, Exception? innerException = null)
            : base(message, innerException)
        {
        }
    }
}
