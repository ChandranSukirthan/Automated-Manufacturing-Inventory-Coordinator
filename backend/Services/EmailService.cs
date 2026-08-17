using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SendGrid;
using SendGrid.Helpers.Mail;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Api.Services
{
    public class EmailService : IEmailService
    {
        private readonly SendGridSettings _settings;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IOptions<SendGridSettings> options, ILogger<EmailService> logger)
        {
            _settings = options.Value;
            _logger = logger;
        }

        public async Task SendOtpEmailAsync(string toEmail, string recipientName, string otpCode)
        {
            try
            {
                var client = new SendGridClient(_settings.ApiKey);

                var from = new EmailAddress(_settings.FromEmail, _settings.FromName);
                var to = new EmailAddress(toEmail, recipientName);
                const string subject = "Your Verification Code";

                var plainTextContent =
                    $"Hi {recipientName},\n\nYour verification code is: {otpCode}\n\nThis code expires in 10 minutes. If you did not request this, please ignore this email.";

                var htmlContent =
                    $"<p>Hi {recipientName},</p>" +
                    $"<p>Your verification code is:</p>" +
                    $"<h2 style=\"letter-spacing:4px;\">{otpCode}</h2>" +
                    $"<p>This code expires in <strong>10 minutes</strong>. If you did not request this, please ignore this email.</p>";

                var msg = MailHelper.CreateSingleEmail(from, to, subject, plainTextContent, htmlContent);

                var response = await client.SendEmailAsync(msg);

                if ((int)response.StatusCode >= 400)
                {
                    var body = await response.Body.ReadAsStringAsync();
                    _logger.LogError(
                        "SendGrid failed to send OTP email to {Email}. Status: {Status}. Body: {Body}",
                        toEmail, response.StatusCode, body);
                    throw new InvalidOperationException("Failed to send verification email.");
                }
            }
            catch (Exception ex) when (ex is not InvalidOperationException)
            {
                _logger.LogError(ex, "Unexpected error sending OTP email to {Email}", toEmail);
                throw new InvalidOperationException("Failed to send verification email.", ex);
            }
        }
    }
}