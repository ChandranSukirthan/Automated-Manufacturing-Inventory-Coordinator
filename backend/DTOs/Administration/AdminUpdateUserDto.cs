using System.ComponentModel.DataAnnotations;

namespace ManufacturingCoordinator.Api.DTOs.Administration
{
    public class AdminUpdateUserDto
    {
        [Required, MaxLength(150)]
        public string FullName { get; set; } = string.Empty;

        [Required, EmailAddress, MaxLength(256)]
        public string Email { get; set; } = string.Empty;
    }
}

