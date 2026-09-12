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

        public StripeService(IConfiguration configuration, ILogger<StripeService> logger)
        {
            _logger = logger;
            // Set the Stripe API key from config/env
            StripeConfiguration.ApiKey = configuration["StripeSettings:SecretKey"]
                ?? Environment.GetEnvironmentVariable("STRIPE_SECRET_KEY")
                ?? throw new InvalidOperationException("Stripe SecretKey is not configured.");
        }

        /// <summary>
        /// Creates a Stripe PaymentIntent. Handles failures safely — never throws uncaught.
        /// </summary>
        public async Task<StripePaymentResult> CreatePaymentIntentAsync(
            decimal amount, string currency, string description)
        {
            try
            {
                // Stripe uses smallest currency unit (cents for USD)
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
                    Success: paymentIntent.Status is "requires_payment_method" or "succeeded" or "requires_confirmation",
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

