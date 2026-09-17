using System.ComponentModel.DataAnnotations;

namespace ManufacturingCoordinator.Api.DTOs.Authentication
{
    public class ResendOtpRequestDto
    {
        [Required, EmailAddress]
        public string Email { get; set; } = string.Empty;
    }
}