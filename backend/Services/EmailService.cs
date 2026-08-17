using System;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Api.Services
{
    public class EmailService : IEmailService
    {
        private readonly EmailSettings _settings;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IOptions<EmailSettings> options, ILogger<EmailService> logger)
        {
            _settings = options.Value;
            _logger = logger;
        }

        public async Task SendOtpEmailAsync(string toEmail, string recipientName, string otpCode)
        {
            try
            {
                if (string.IsNullOrEmpty(_settings.EmailUser) || string.IsNullOrEmpty(_settings.EmailPass))
                {
                    _logger.LogWarning("Email credentials are not configured. Cannot send OTP to {Email}", toEmail);
                    return;
                }

                using var client = new SmtpClient(_settings.SmtpHost, _settings.SmtpPort)
                {
                    Credentials = new NetworkCredential(_settings.EmailUser, _settings.EmailPass),
                    EnableSsl = true
                };

                var fromAddress = new MailAddress(_settings.EmailUser, _settings.FromName);
                var toAddress = new MailAddress(toEmail, recipientName);

                using var message = new MailMessage(fromAddress, toAddress)
                {
                    Subject = "Your Verification Code",
                    Body = $"<p>Hi {recipientName},</p>" +
                           $"<p>Your verification code is:</p>" +
                           $"<h2 style=\"letter-spacing:4px;\">{otpCode}</h2>" +
                           $"<p>This code expires in <strong>10 minutes</strong>. If you did not request this, please ignore this email.</p>",
                    IsBodyHtml = true
                };

                await client.SendMailAsync(message);
                _logger.LogInformation("Successfully sent OTP email to {Email}", toEmail);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error sending OTP email to {Email}", toEmail);
                throw new InvalidOperationException("Failed to send verification email.", ex);
            }
        }
    }
}