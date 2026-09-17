using System.ComponentModel.DataAnnotations;

namespace ManufacturingCoordinator.Api.DTOs.Authentication
{
    public class GoogleLoginRequestDto
    {
        [Required]
        public string TokenId { get; set; } = string.Empty;
    }
}
