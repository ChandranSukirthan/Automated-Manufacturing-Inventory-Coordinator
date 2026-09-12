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
                    throw new AuthException("Server email credentials are not configured.");
                }

                using var client = new SmtpClient(_settings.SmtpHost, _settings.SmtpPort)
                {
                    UseDefaultCredentials = false,
                    Credentials = new NetworkCredential(_settings.EmailUser.Trim(), _settings.EmailPass.Trim()),
                    EnableSsl = true,
                    DeliveryMethod = SmtpDeliveryMethod.Network
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
                throw new AuthException($"Failed to send verification email: {ex.Message}");
            }
        }

        public async Task SendPurchaseOrderEmailAsync(
            string toEmail,
            string supplierName,
            string poNumber,
            byte[] pdfAttachment,
            string attachmentFileName)
        {
            if (string.IsNullOrEmpty(_settings.EmailUser) || string.IsNullOrEmpty(_settings.EmailPass))
            {
                _logger.LogWarning("Email credentials not configured. Cannot send PO email to {Email}", toEmail);
                throw new InvalidOperationException("Server email credentials are not configured.");
            }

            using var client = new SmtpClient(_settings.SmtpHost, _settings.SmtpPort)
            {
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(_settings.EmailUser.Trim(), _settings.EmailPass.Trim()),
                EnableSsl = true,
                DeliveryMethod = SmtpDeliveryMethod.Network
            };

            var fromAddress = new MailAddress(_settings.EmailUser, _settings.FromName);
            var toAddress = new MailAddress(toEmail, supplierName);

            using var message = new MailMessage(fromAddress, toAddress)
            {
                Subject = $"Purchase Order {poNumber} — Automated Manufacturing Inventory Coordinator",
                Body = $"<p>Dear {supplierName},</p>" +
                       $"<p>Please find attached Purchase Order <strong>{poNumber}</strong> from Automated Manufacturing Inventory Coordinator.</p>" +
                       $"<p>Total amount has been processed successfully.</p>" +
                       $"<p>Thank you for your partnership.</p>",
                IsBodyHtml = true
            };

            using var pdfStream = new MemoryStream(pdfAttachment);
            var attachment = new Attachment(pdfStream, attachmentFileName, "application/pdf");
            message.Attachments.Add(attachment);

            await client.SendMailAsync(message);
            _logger.LogInformation("Successfully sent PO email {PoNumber} to {Email}", poNumber, toEmail);
        }
    }
}