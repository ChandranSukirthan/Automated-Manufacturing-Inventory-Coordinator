using System;
using System.Net.Http.Headers;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace backend.Services
{
    /// <summary>
    /// Server-side proxy for the configured QR provider. The provider base URL is
    /// fixed in Program.cs, so callers cannot use this service for arbitrary URLs.
    /// </summary>
    public sealed class BarcodeService : IBarcodeService
    {
        private const int MaximumImageBytes = 1_000_000;
        private static readonly Regex RollIdentifierPattern = new(
            "^[A-Za-z0-9][A-Za-z0-9_-]{1,63}$",
            RegexOptions.Compiled | RegexOptions.CultureInvariant);

        private readonly HttpClient _httpClient;
        private readonly IMemoryCache _cache;
        private readonly ILogger<BarcodeService> _logger;

        public BarcodeService(
            HttpClient httpClient,
            IMemoryCache cache,
            ILogger<BarcodeService> logger)
        {
            _httpClient = httpClient;
            _cache = cache;
            _logger = logger;
        }

        public async Task<QrCodeImage> GenerateInventoryRollQrAsync(
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
                return cachedImage!;
            }

            var encodedIdentifier = Uri.EscapeDataString(rollIdentifier);
            using var request = new HttpRequestMessage(
                HttpMethod.Get,
                $"v1/create-qr-code/?size=300x300&format=png&data={encodedIdentifier}");
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("image/png"));

            try
            {
                using var response = await _httpClient.SendAsync(
                    request,
                    HttpCompletionOption.ResponseHeadersRead,
                    cancellationToken);

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning(
                        "QR provider returned {StatusCode} for inventory roll {RollIdentifier}.",
                        (int)response.StatusCode,
                        rollIdentifier);
                    throw new QrCodeProviderException("The QR provider could not generate the code.");
                }

                var mediaType = response.Content.Headers.ContentType?.MediaType;
                if (!string.Equals(mediaType, "image/png", StringComparison.OrdinalIgnoreCase))
                {
                    throw new QrCodeProviderException("The QR provider returned an unexpected content type.");
                }

                if (response.Content.Headers.ContentLength is > MaximumImageBytes)
                {
                    throw new QrCodeProviderException("The QR provider returned an oversized image.");
                }

                var imageBytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
                if (imageBytes.Length == 0 || imageBytes.Length > MaximumImageBytes)
                {
                    throw new QrCodeProviderException("The QR provider returned an invalid image.");
                }

                var image = new QrCodeImage(imageBytes, "image/png");
                _cache.Set(cacheKey, image, TimeSpan.FromHours(12));
                return image;
            }
            catch (QrCodeProviderException)
            {
                throw;
            }
            catch (HttpRequestException exception)
            {
                _logger.LogError(exception, "QR provider request failed for inventory roll {RollIdentifier}.", rollIdentifier);
                throw new QrCodeProviderException("The QR provider is unavailable.", exception);
            }
            catch (TaskCanceledException exception) when (!cancellationToken.IsCancellationRequested)
            {
                _logger.LogWarning(exception, "QR provider timed out for inventory roll {RollIdentifier}.", rollIdentifier);
                throw new QrCodeProviderException("The QR provider timed out.", exception);
            }
        }
    }
}
