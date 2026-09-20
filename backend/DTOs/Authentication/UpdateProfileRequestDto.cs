using System.ComponentModel.DataAnnotations;

namespace ManufacturingCoordinator.Api.DTOs.Authentication
{
    public class UpdateProfileRequestDto
    {
        [Required]
        [StringLength(200)]
        public string FullName { get; set; } = string.Empty;
    }
}