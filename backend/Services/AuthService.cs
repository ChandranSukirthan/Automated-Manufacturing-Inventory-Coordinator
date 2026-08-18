using System;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Api.DTOs.Authentication;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Models.Authentication;

namespace ManufacturingCoordinator.Api.Services
{
    public class AuthService : IAuthService
    {
        private readonly ApplicationDbContext _db;
        private readonly IPasswordHasher _passwordHasher;
        private readonly IJwtTokenService _jwtTokenService;
        private readonly IEmailService _emailService;
        private readonly JwtSettings _jwtSettings;

        private const int OtpExpiryMinutes = 10;
        private const int OtpResendCooldownSeconds = 60;

        public AuthService(
            ApplicationDbContext db,
            IPasswordHasher passwordHasher,
            IJwtTokenService jwtTokenService,
            IEmailService emailService,
            Microsoft.Extensions.Options.IOptions<JwtSettings> jwtOptions)
        {
            _db = db;
            _passwordHasher = passwordHasher;
            _jwtTokenService = jwtTokenService;
            _emailService = emailService;
            _jwtSettings = jwtOptions.Value;
        }

        public async Task<AuthResponseDto> RegisterAsync(RegisterRequestDto request)
        {
            var emailNormalized = request.Email.Trim().ToLowerInvariant();

            var existingUser = await _db.Users
                .FirstOrDefaultAsync(u => u.Email == emailNormalized);

            if (existingUser != null)
            {
                throw new AuthException("An account with this email already exists.", HttpStatusCode.Conflict);
            }

            var user = new User
            {
                FullName = request.FullName.Trim(),
                Email = emailNormalized,
                PasswordHash = _passwordHasher.HashPassword(request.Password),
                Role = request.Role,
                IsEmailVerified = true,
                IsActive = true
            };

            _db.Users.Add(user);
            await _db.SaveChangesAsync();

            return await IssueAuthResponseAsync(user);
        }

        public async Task<MessageResponseDto> VerifyOtpAsync(VerifyOtpRequestDto request)
        {
            var emailNormalized = request.Email.Trim().ToLowerInvariant();

            var user = await _db.Users
                .FirstOrDefaultAsync(u => u.Email == emailNormalized);

            if (user == null)
            {
                throw new AuthException("Invalid email or code.", HttpStatusCode.BadRequest);
            }

            if (user.IsEmailVerified)
            {
                return new MessageResponseDto { Success = true, Message = "Email is already verified." };
            }

            var otp = await _db.OtpVerifications
                .Where(o => o.UserId == user.Id
                            && o.Purpose == OtpPurpose.Registration
                            && !o.IsUsed)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            if (otp == null || otp.Code != request.Code)
            {
                throw new AuthException("Invalid email or code.", HttpStatusCode.BadRequest);
            }

            if (otp.ExpiresAt < DateTime.UtcNow)
            {
                throw new AuthException("This code has expired. Please request a new one.", HttpStatusCode.BadRequest);
            }

            otp.IsUsed = true;
            user.IsEmailVerified = true;
            user.UpdatedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync();

            return new MessageResponseDto
            {
                Success = true,
                Message = "Email verified successfully. You can now log in."
            };
        }

        public async Task<MessageResponseDto> ResendOtpAsync(ResendOtpRequestDto request)
        {
            var emailNormalized = request.Email.Trim().ToLowerInvariant();

            var user = await _db.Users
                .FirstOrDefaultAsync(u => u.Email == emailNormalized);

            // Don't reveal whether the account exists — return a generic success message either way
            if (user == null || user.IsEmailVerified)
            {
                return new MessageResponseDto
                {
                    Success = true,
                    Message = "If an account exists and is not yet verified, a new code has been sent."
                };
            }

            var recentOtp = await _db.OtpVerifications
                .Where(o => o.UserId == user.Id && o.Purpose == OtpPurpose.Registration)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            if (recentOtp != null &&
                recentOtp.CreatedAt.AddSeconds(OtpResendCooldownSeconds) > DateTime.UtcNow)
            {
                throw new AuthException(
                    $"Please wait before requesting another code.",
                    HttpStatusCode.TooManyRequests);
            }

            await IssueAndSendOtpAsync(user, OtpPurpose.Registration);

            return new MessageResponseDto
            {
                Success = true,
                Message = "If an account exists and is not yet verified, a new code has been sent."
            };
        }

        public async Task<AuthResponseDto> LoginAsync(LoginRequestDto request)
        {
            var emailNormalized = request.Email.Trim().ToLowerInvariant();

            var user = await _db.Users
                .FirstOrDefaultAsync(u => u.Email == emailNormalized);

            if (user == null || !_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
            {
                throw new AuthException("Invalid email or password.", HttpStatusCode.Unauthorized);
            }

            if (!user.IsActive)
            {
                throw new AuthException("This account has been deactivated. Contact an administrator.", HttpStatusCode.Forbidden);
            }

            return await IssueAuthResponseAsync(user);
        }

        public async Task<AuthResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request)
        {
            var incomingHash = _jwtTokenService.HashToken(request.RefreshToken);

            var storedToken = await _db.RefreshTokens
                .Include(r => r.User)
                .FirstOrDefaultAsync(r => r.TokenHash == incomingHash);

            if (storedToken == null || storedToken.IsRevoked || storedToken.ExpiresAt < DateTime.UtcNow)
            {
                throw new AuthException("Invalid or expired refresh token.", HttpStatusCode.Unauthorized);
            }

            if (storedToken.User == null || !storedToken.User.IsActive)
            {
                throw new AuthException("Account is not available.", HttpStatusCode.Forbidden);
            }

            // Rotate: revoke the old refresh token, issue a new pair
            storedToken.IsRevoked = true;
            await _db.SaveChangesAsync();

            return await IssueAuthResponseAsync(storedToken.User);
        }

        // ---------- Private helpers ----------

        private async Task IssueAndSendOtpAsync(User user, OtpPurpose purpose)
        {
            var code = GenerateNumericOtp(6);

            var otp = new OtpVerification
            {
                UserId = user.Id,
                Code = code,
                Purpose = purpose,
                ExpiresAt = DateTime.UtcNow.AddMinutes(OtpExpiryMinutes),
                IsUsed = false
            };

            _db.OtpVerifications.Add(otp);
            await _db.SaveChangesAsync();

            await _emailService.SendOtpEmailAsync(user.Email, user.FullName, code);
        }

        private static string GenerateNumericOtp(int length)
        {
            var maxExclusive = (int)Math.Pow(10, length);
            var value = RandomNumberGenerator.GetInt32(0, maxExclusive);
            return value.ToString(new string('0', length));
        }

        private async Task<AuthResponseDto> IssueAuthResponseAsync(User user)
        {
            var (accessToken, expiresAt) = _jwtTokenService.GenerateAccessToken(user);
            var rawRefreshToken = _jwtTokenService.GenerateRefreshToken();
            var refreshTokenHash = _jwtTokenService.HashToken(rawRefreshToken);

            var refreshTokenEntity = new RefreshToken
            {
                UserId = user.Id,
                TokenHash = refreshTokenHash,
                ExpiresAt = DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenExpiryDays),
                IsRevoked = false
            };

            _db.RefreshTokens.Add(refreshTokenEntity);
            await _db.SaveChangesAsync();

            return new AuthResponseDto
            {
                AccessToken = accessToken,
                RefreshToken = rawRefreshToken,
                AccessTokenExpiresAt = expiresAt,
                User = new UserSummaryDto
                {
                    Id = user.Id,
                    FullName = user.FullName,
                    Email = user.Email,
                    Role = user.Role
                }
            };
        }
    }
}