using System.Threading.Tasks;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public record StripePaymentResult(
        bool Success,
        string? PaymentIntentId,
        string? Status,
        string? ErrorMessage
    );

    public interface IStripeService
    {
        /// <summary>
        /// Creates a Stripe PaymentIntent for the given amount and returns the result.
        /// AI must never call Stripe directly — all calls go through this service.
        /// </summary>
        Task<StripePaymentResult> CreatePaymentIntentAsync(decimal amount, string currency, string description);
    }
}

