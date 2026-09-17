namespace ManufacturingCoordinator.Api.DTOs.Authentication
{
    public class GoogleLoginResponseDto
    {
        public bool RequiresRoleSelection { get; set; }
        public string? Email { get; set; }
        public string? Name { get; set; }
        public AuthResponseDto? AuthResponse { get; set; }
    }
}
