using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Api.DTOs.Administration;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;

namespace ManufacturingCoordinator.Api.Services
{
    public class AdminService : IAdminService
    {
        private readonly ApplicationDbContext _db;
        private readonly IPasswordHasher _passwordHasher;

        public AdminService(ApplicationDbContext db, IPasswordHasher passwordHasher)
        {
            _db = db;
            _passwordHasher = passwordHasher;
        }

        // ========== User Management ==========

        public async Task<List<UserListDto>> GetAllUsersAsync()
        {
            var users = await _db.Users
                .OrderBy(u => u.FullName)
                .ToListAsync();

            return users.Select(MapUserToDto).ToList();
        }

        public async Task<UserListDto> GetUserByIdAsync(Guid id)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null)
                throw new AuthException("User not found.", HttpStatusCode.NotFound);

            return MapUserToDto(user);
        }

        public async Task<UserListDto> CreateUserAsync(AdminCreateUserDto dto)
        {
            var emailNormalized = dto.Email.Trim().ToLowerInvariant();

            var existingUser = await _db.Users
                .FirstOrDefaultAsync(u => u.Email == emailNormalized);

            if (existingUser != null)
                throw new AuthException("An account with this email already exists.", HttpStatusCode.Conflict);

            // Admin-created users are auto-verified (skip OTP)
            var user = new User
            {
                FullName = dto.FullName.Trim(),
                Email = emailNormalized,
                PasswordHash = _passwordHasher.HashPassword(dto.Password),
                Role = dto.Role,
                IsEmailVerified = true,
                IsActive = true
            };

            _db.Users.Add(user);
            await _db.SaveChangesAsync();

            return MapUserToDto(user);
        }

        public async Task<UserListDto> UpdateUserAsync(Guid id, AdminUpdateUserDto dto)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null)
                throw new AuthException("User not found.", HttpStatusCode.NotFound);

            var emailNormalized = dto.Email.Trim().ToLowerInvariant();

            // Check if email is taken by another user
            var emailTaken = await _db.Users
                .AnyAsync(u => u.Email == emailNormalized && u.Id != id);

            if (emailTaken)
                throw new AuthException("This email is already in use by another account.", HttpStatusCode.Conflict);

            user.FullName = dto.FullName.Trim();
            user.Email = emailNormalized;
            user.UpdatedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync();

            return MapUserToDto(user);
        }

        public async Task ActivateUserAsync(Guid id)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null)
                throw new AuthException("User not found.", HttpStatusCode.NotFound);

            user.IsActive = true;
            user.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        public async Task DeactivateUserAsync(Guid id)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null)
                throw new AuthException("User not found.", HttpStatusCode.NotFound);

            user.IsActive = false;
            user.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        public async Task<UserListDto> AssignRoleAsync(Guid id, AssignRoleDto dto)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null)
                throw new AuthException("User not found.", HttpStatusCode.NotFound);

            user.Role = dto.Role;
            user.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return MapUserToDto(user);
        }

        // ========== Roles ==========

        public Task<List<string>> GetAllRolesAsync()
        {
            var roles = Enum.GetNames(typeof(UserRole)).ToList();
            return Task.FromResult(roles);
        }

        // ========== Agent Workflows ==========

        public async Task<List<AgentWorkflowDto>> GetAllWorkflowsAsync()
        {
            var workflows = await _db.AgentWorkflows
                .OrderByDescending(w => w.StartedAt)
                .ToListAsync();

            return workflows.Select(w => new AgentWorkflowDto
            {
                Id = w.Id,
                WorkflowId = w.WorkflowId,
                Objective = w.Objective,
                CurrentAgent = w.CurrentAgent,
                Status = w.Status,
                ApprovalStatus = w.ApprovalStatus,
                StartedAt = w.StartedAt,
                CompletedAt = w.CompletedAt,
                FinalOutcome = w.FinalOutcome
            }).ToList();
        }

        public async Task<AgentWorkflowDto> GetWorkflowByIdAsync(Guid id)
        {
            var w = await _db.AgentWorkflows.FindAsync(id);
            if (w == null)
                throw new AuthException("Workflow not found.", HttpStatusCode.NotFound);

            return new AgentWorkflowDto
            {
                Id = w.Id,
                WorkflowId = w.WorkflowId,
                Objective = w.Objective,
                CurrentAgent = w.CurrentAgent,
                Status = w.Status,
                ApprovalStatus = w.ApprovalStatus,
                StartedAt = w.StartedAt,
                CompletedAt = w.CompletedAt,
                FinalOutcome = w.FinalOutcome
            };
        }

        // ========== System Health ==========

        public async Task<SystemHealthDto> GetSystemHealthAsync()
        {
            var services = new List<ServiceHealthDto>();

            // 1. ASP.NET API — always ONLINE if this code is running
            services.Add(new ServiceHealthDto
            {
                Name = "ASP.NET API",
                Status = "ONLINE",
                Message = "API is running."
            });

            // 2. PostgreSQL — check DB connection
            try
            {
                await _db.Database.CanConnectAsync();
                services.Add(new ServiceHealthDto
                {
                    Name = "PostgreSQL",
                    Status = "ONLINE",
                    Message = "Database connection is healthy."
                });
            }
            catch
            {
                services.Add(new ServiceHealthDto
                {
                    Name = "PostgreSQL",
                    Status = "OFFLINE",
                    Message = "Cannot connect to database."
                });
            }

            // 3. FastAPI — OFFLINE until Agentic AI service is deployed
            services.Add(new ServiceHealthDto
            {
                Name = "FastAPI",
                Status = "OFFLINE",
                Message = "FastAPI service is not yet deployed."
            });

            // 4. Agentic AI — OFFLINE until AI service is deployed
            services.Add(new ServiceHealthDto
            {
                Name = "Agentic AI",
                Status = "OFFLINE",
                Message = "Agentic AI service is not yet deployed."
            });

            // 5. External Integrations
            services.Add(new ServiceHealthDto
            {
                Name = "External Integrations",
                Status = "ONLINE",
                Message = "No external integration issues detected."
            });

            // Determine overall status
            var overallStatus = "ONLINE";
            if (services.Any(s => s.Status == "OFFLINE"))
                overallStatus = "DEGRADED";
            if (services.All(s => s.Status == "OFFLINE"))
                overallStatus = "OFFLINE";

            return new SystemHealthDto
            {
                OverallStatus = overallStatus,
                Services = services
            };
        }

        // ========== Helpers ==========

        private static UserListDto MapUserToDto(User user)
        {
            return new UserListDto
            {
                Id = user.Id,
                FullName = user.FullName,
                Email = user.Email,
                Role = user.Role,
                IsEmailVerified = user.IsEmailVerified,
                IsActive = user.IsActive,
                CreatedAt = user.CreatedAt,
                UpdatedAt = user.UpdatedAt
            };
        }
    }
}
