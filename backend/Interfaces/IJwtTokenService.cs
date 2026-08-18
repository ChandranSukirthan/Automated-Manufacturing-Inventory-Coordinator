using System;
using ManufacturingCoordinator.Models.Authentication;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IJwtTokenService
    {
        (string token, DateTime expiresAt) GenerateAccessToken(User user);
        string GenerateRefreshToken();
        string HashToken(string token);
    }
}