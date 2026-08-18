using System.Threading.Tasks;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IEmailService
    {
        Task SendOtpEmailAsync(string toEmail, string recipientName, string otpCode);
    }
}