using System;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using QRCoder;

namespace backend.Services
{
    /// <summary>
    /// Generates inventory-roll QR images locally. Roll identifiers are never
    /// sent to an external QR provider.
    /// </summary>
    public sealed class BarcodeService : IBarcodeService
    {
        private const int MaximumImageBytes = 1_000_000;
        private static readonly Regex RollIdentifierPattern = new(
            "^[A-Za-z0-9][A-Za-z0-9_-]{1,63}$",
            RegexOptions.Compiled | RegexOptions.CultureInvariant);

        private readonly IMemoryCache _cache;
        private readonly ILogger<BarcodeService> _logger;

        public BarcodeService(
            IMemoryCache cache,
            ILogger<BarcodeService> logger)
        {
            _cache = cache;
            _logger = logger;
        }

        public Task<QrCodeImage> GenerateInventoryRollQrAsync(
            string rollIdentifier,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(rollIdentifier) ||
                !RollIdentifierPattern.IsMatch(rollIdentifier))
            {
                throw new ArgumentException(
                    "Inventory-roll identifiers must contain only letters, numbers, hyphens, or underscores.",
                    nameof(rollIdentifier));
            }

            var cacheKey = $"inventory-roll-qr:{rollIdentifier}";
            if (_cache.TryGetValue<QrCodeImage>(cacheKey, out var cachedImage))
            {
                return Task.FromResult(cachedImage!);
            }

            try
            {
                cancellationToken.ThrowIfCancellationRequested();
                using var generator = new QRCodeGenerator();
                using var data = generator.CreateQrCode(
                    rollIdentifier,
                    QRCodeGenerator.ECCLevel.Q);
                var qrCode = new PngByteQRCode(data);
                var imageBytes = qrCode.GetGraphic(pixelsPerModule: 10);

                if (imageBytes.Length == 0 || imageBytes.Length > MaximumImageBytes)
                {
                    throw new QrCodeProviderException("The QR image could not be generated.");
                }

                var image = new QrCodeImage(imageBytes, "image/png");
                _cache.Set(cacheKey, image, TimeSpan.FromHours(12));
                return Task.FromResult(image);
            }
            catch (QrCodeProviderException)
            {
                throw;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Local QR generation failed for inventory roll {RollIdentifier}.", rollIdentifier);
                throw new QrCodeProviderException("The QR image could not be generated.", exception);
            }
        }
    }
}
