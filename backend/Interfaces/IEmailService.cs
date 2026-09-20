using System.Threading.Tasks;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IEmailService
    {
        Task SendOtpEmailAsync(string toEmail, string recipientName, string otpCode);

        /// <summary>
        /// Sends a Purchase Order PDF to the supplier's contact email.
        /// </summary>
        Task SendPurchaseOrderEmailAsync(
            string toEmail,
            string supplierName,
            string poNumber,
            byte[] pdfAttachment,
            string attachmentFileName);
    }
}