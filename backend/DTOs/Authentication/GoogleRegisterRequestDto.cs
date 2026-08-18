using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Authentication
{
    public class GoogleRegisterRequestDto
    {
        [Required]
        public string TokenId { get; set; } = string.Empty;

        [Required]
        public UserRole Role { get; set; }
    }
}
