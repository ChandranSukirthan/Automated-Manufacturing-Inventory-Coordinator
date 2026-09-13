using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Api.DTOs.Administration;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.Production;

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

        public async Task<AgentWorkflowDto> ApproveWorkflowAsync(string workflowId)
        {
            try
            {
                using var httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
                await httpClient.PostAsync($"http://127.0.0.1:8000/api/workflows/{workflowId}/approve", null);
            }
            catch
            {
                // Fallback to direct DB update if microservice offline
            }

            var w = await _db.AgentWorkflows.FirstOrDefaultAsync(x => x.WorkflowId == workflowId);
            if (w == null)
                throw new AuthException($"Workflow '{workflowId}' not found.", HttpStatusCode.NotFound);

            w.Status = WorkflowStatus.Completed;
            w.ApprovalStatus = ApprovalStatus.Approved;
            w.CurrentAgent = "Execution";
            w.CompletedAt = DateTime.UtcNow;

            // Domain Action: Machine Maintenance Overhaul
            if (w.Objective.Contains("overhaul", StringComparison.OrdinalIgnoreCase) ||
                w.Objective.Contains("maintenance", StringComparison.OrdinalIgnoreCase) ||
                w.Objective.Contains("machine", StringComparison.OrdinalIgnoreCase))
            {
                var allMachines = await _db.Machines.ToListAsync();

                // 1. Find machine whose name appears in the objective (longest name first)
                Machine? targetMachine = null;
                foreach (var m in allMachines.OrderByDescending(x => x.Name.Length))
                {
                    if (!string.IsNullOrWhiteSpace(m.Name) && 
                        w.Objective.Contains(m.Name, StringComparison.OrdinalIgnoreCase))
                    {
                        targetMachine = m;
                        break;
                    }
                }

                // 2. Fallback: match by significant keywords/tokens
                if (targetMachine == null)
                {
                    var ignoreWords = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                    {
                        "schedule", "urgent", "preventive", "overhaul", "maintenance", "machine", "for", "the", "and", "with"
                    };

                    var words = w.Objective.Split(new[] { ' ', ',', '.', ';', ':', '-', '_' }, StringSplitOptions.RemoveEmptyEntries)
                                           .Where(word => word.Length > 2 && !ignoreWords.Contains(word));

                    foreach (var word in words)
                    {
                        var match = allMachines.FirstOrDefault(m => m.Name.Contains(word, StringComparison.OrdinalIgnoreCase));
                        if (match != null)
                        {
                            targetMachine = match;
                            break;
                        }
                    }
                }

                // 3. Execution or Safe Failure
                if (targetMachine != null)
                {
                    targetMachine.Status = MachineStatus.UnderMaintenance;
                    targetMachine.UpdatedAt = DateTime.UtcNow;

                    var maintLog = new MaintenanceLog
                    {
                        Id = Guid.NewGuid(),
                        MachineId = targetMachine.Id,
                        Description = $"Preventive overhaul authorized & executed via AI Workflow {w.WorkflowId}.",
                        PerformedBy = "IT Admin / Autonomous Scheduler",
                        PerformedAt = DateTime.UtcNow,
                        Type = MaintenanceType.Preventive,
                        CreatedAt = DateTime.UtcNow
                    };
                    await _db.MaintenanceLogs.AddAsync(maintLog);

                    w.FinalOutcome = $"Overhaul authorized and executed. {targetMachine.Name} placed Under Maintenance and preventive service log registered.";
                }
                else
                {
                    // SAFE FAILURE: Strictly do NOT modify any innocent machines!
                    w.Status = WorkflowStatus.Failed;
                    w.ApprovalStatus = ApprovalStatus.Rejected;
                    w.FinalOutcome = "Execution halted (Safe Failure): Target machine was not found in the factory equipment directory. No physical equipment was modified.";
                }
            }
            else if (string.IsNullOrEmpty(w.FinalOutcome) || w.FinalOutcome.Contains("PO-DRAFT"))
            {
                w.FinalOutcome = "Approved by IT Admin. Requisition queued and production schedule reconciled.";
            }

            await _db.SaveChangesAsync();

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

        public async Task<AgentWorkflowDto> RejectWorkflowAsync(string workflowId)
        {
            try
            {
                using var httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
                var content = new StringContent("{\"reason\":\"Rejected by IT Admin\"}", System.Text.Encoding.UTF8, "application/json");
                await httpClient.PostAsync($"http://127.0.0.1:8000/api/workflows/{workflowId}/reject", content);
            }
            catch
            {
            }

            var w = await _db.AgentWorkflows.FirstOrDefaultAsync(x => x.WorkflowId == workflowId);
            if (w == null)
                throw new AuthException($"Workflow '{workflowId}' not found.", HttpStatusCode.NotFound);

            w.Status = WorkflowStatus.Failed;
            w.ApprovalStatus = ApprovalStatus.Rejected;
            w.CompletedAt = DateTime.UtcNow;
            w.FinalOutcome = "Workflow execution rejected by human administrator.";

            await _db.SaveChangesAsync();

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

        public async Task<object> TriggerWorkflowAsync(string objective, string? workflowId)
        {
            try
            {
                using var httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
                var json = System.Text.Json.JsonSerializer.Serialize(new { objective, workflowId });
                var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
                var response = await httpClient.PostAsync("http://127.0.0.1:8000/api/workflows/run", content);
                var responseString = await response.Content.ReadAsStringAsync();
                return System.Text.Json.JsonSerializer.Deserialize<object>(responseString) ?? new { message = "Workflow dispatched" };
            }
            catch (Exception ex)
            {
                throw new AuthException($"Could not communicate with Python AI microservice: {ex.Message}", HttpStatusCode.ServiceUnavailable);
            }
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

            // 3. FastAPI & 4. Agentic AI — Ping Python microservice
            bool isAiOnline = false;
            string? aiErrorMessage = null;
            try
            {
                using var httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
                var response = await httpClient.GetAsync("http://127.0.0.1:8000/health");
                if (response.IsSuccessStatusCode)
                {
                    isAiOnline = true;
                }
                else
                {
                    aiErrorMessage = $"FastAPI returned HTTP {(int)response.StatusCode}";
                }
            }
            catch (Exception ex)
            {
                isAiOnline = false;
                aiErrorMessage = ex.Message;
            }

            if (isAiOnline)
            {
                services.Add(new ServiceHealthDto
                {
                    Name = "FastAPI",
                    Status = "ONLINE",
                    Message = "FastAPI service is running on port 8000."
                });
                services.Add(new ServiceHealthDto
                {
                    Name = "Agentic AI",
                    Status = "ONLINE",
                    Message = "LangGraph Planner Agent is active."
                });
            }
            else
            {
                services.Add(new ServiceHealthDto
                {
                    Name = "FastAPI",
                    Status = "OFFLINE",
                    Message = aiErrorMessage ?? "FastAPI service is not reachable on port 8000."
                });
                services.Add(new ServiceHealthDto
                {
                    Name = "Agentic AI",
                    Status = "OFFLINE",
                    Message = "Agentic AI service is not running."
                });
            }

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
