using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Authentication;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IAuthService
    {
        Task<MessageResponseDto> RegisterAsync(RegisterRequestDto request);
        Task<MessageResponseDto> VerifyOtpAsync(VerifyOtpRequestDto request);
        Task<MessageResponseDto> ResendOtpAsync(ResendOtpRequestDto request);
        Task<AuthResponseDto> LoginAsync(LoginRequestDto request);
        Task<AuthResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request);
    }
}