using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Stripe;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public class StripeService : IStripeService
    {
        private readonly ILogger<StripeService> _logger;
        private readonly string? _apiKey;

        public StripeService(IConfiguration configuration, ILogger<StripeService> logger)
        {
            _logger = logger;
            _apiKey = configuration["StripeSettings:SecretKey"]
                ?? Environment.GetEnvironmentVariable("STRIPE_SECRET_KEY");
        }

        public async Task<StripePaymentResult> CreatePaymentIntentAsync(
            decimal amount, string currency, string description)
        {
            if (string.IsNullOrWhiteSpace(_apiKey))
            {
                _logger.LogWarning(
                    "A payment was requested while Stripe SecretKey is not configured.");
                return new StripePaymentResult(
                    Success: false,
                    PaymentIntentId: null,
                    Status: "unavailable",
                    ErrorMessage: "Payment processing is unavailable until Stripe is configured."
                );
            }

            StripeConfiguration.ApiKey = _apiKey;
            var apiKey = _apiKey;
            var isPlaceholder = string.IsNullOrWhiteSpace(apiKey) ||
                                apiKey.Contains("placeholder", StringComparison.OrdinalIgnoreCase) ||
                                apiKey.StartsWith("sk_test_placeholder", StringComparison.OrdinalIgnoreCase);

            if (isPlaceholder)
            {
                return new StripePaymentResult(false, null, "unavailable", "Configure a valid Stripe key before processing payment.");
            }

            try
            {
                // Stripe uses smallest currency unit (cents for LKR)
                var amountInCents = (long)Math.Round(amount * 100, 0);

                var options = new PaymentIntentCreateOptions
                {
                    Amount = amountInCents,
                    Currency = currency.ToLowerInvariant(),
                    Description = description,
                    // Automatic payment methods for sandbox testing
                    AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
                    {
                        Enabled = true,
                    },
                    Metadata = new System.Collections.Generic.Dictionary<string, string>
                    {
                        { "source", "ManufacturingCoordinator" },
                        { "description", description }
                    }
                };

                var service = new PaymentIntentService();
                var paymentIntent = await service.CreateAsync(options);

                _logger.LogInformation("Stripe PaymentIntent created: {Id}, Status: {Status}",
                    paymentIntent.Id, paymentIntent.Status);

                return new StripePaymentResult(
                    Success: paymentIntent.Status == "succeeded",
                    PaymentIntentId: paymentIntent.Id,
                    Status: paymentIntent.Status,
                    ErrorMessage: null
                );
            }
            catch (StripeException ex)
            {
                _logger.LogError(ex, "Stripe payment failed: {Message}", ex.Message);

                return new StripePaymentResult(
                    Success: false,
                    PaymentIntentId: null,
                    Status: "failed",
                    ErrorMessage: ex.Message
                );
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error during Stripe payment: {Message}", ex.Message);
                return new StripePaymentResult(
                    Success: false,
                    PaymentIntentId: null,
                    Status: "error",
                    ErrorMessage: ex.Message
                );
            }
        }
    }
}

