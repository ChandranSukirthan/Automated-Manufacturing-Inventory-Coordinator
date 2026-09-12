using System.ComponentModel.DataAnnotations;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.DTOs.Administration
{
    public class AssignRoleDto
    {
        [Required]
        public UserRole Role { get; set; }
    }
}

