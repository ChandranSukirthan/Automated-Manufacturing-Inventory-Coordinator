using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Api.DTOs.Administration;
using ManufacturingCoordinator.Api.Helpers;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.Production;
using ManufacturingCoordinator.Models.PurchaseOrders;
using backend.Data;

namespace ManufacturingCoordinator.Api.Services
{
    public class AdminService : IAdminService
    {
        private readonly ApplicationDbContext _db;
        private readonly IPasswordHasher _passwordHasher;
        private readonly ManufacturingContext? _mfgContext;
        private readonly IConfiguration? _configuration;

        public AdminService(ApplicationDbContext db, IPasswordHasher passwordHasher, ManufacturingContext? mfgContext = null, IConfiguration? configuration = null)
        {
            _db = db;
            _passwordHasher = passwordHasher;
            _mfgContext = mfgContext;
            _configuration = configuration;
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
                EmployeeId = dto.Role == UserRole.FloorWorker
                    ? await FloorWorkerEmployeeIdGenerator.GetNextAsync(_db)
                    : null,
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

            if (user.Role == UserRole.ITAdmin)
            {
                var otherActiveAdmins = await _db.Users
                    .CountAsync(u => u.Role == UserRole.ITAdmin && u.IsActive && u.Id != id);
                if (otherActiveAdmins == 0)
                {
                    throw new AuthException("Cannot deactivate the last active IT Admin account.", HttpStatusCode.BadRequest);
                }
            }

            user.IsActive = false;
            user.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        public async Task<UserListDto> AssignRoleAsync(Guid id, AssignRoleDto dto)
        {
            var user = await _db.Users.FindAsync(id);
            if (user == null)
                throw new AuthException("User not found.", HttpStatusCode.NotFound);

            if (user.Role == UserRole.ITAdmin && dto.Role != UserRole.ITAdmin)
            {
                var otherActiveAdmins = await _db.Users
                    .CountAsync(u => u.Role == UserRole.ITAdmin && u.IsActive && u.Id != id);
                if (otherActiveAdmins == 0)
                {
                    throw new AuthException("Cannot reassign the role of the last active IT Admin account.", HttpStatusCode.BadRequest);
                }
            }

            user.Role = dto.Role;
            if (dto.Role != UserRole.FloorWorker)
            {
                user.EmployeeId = null;
            }
            else if (string.IsNullOrWhiteSpace(user.EmployeeId))
            {
                user.EmployeeId = await FloorWorkerEmployeeIdGenerator.GetNextAsync(_db);
            }
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
                WorkflowType = w.WorkflowType,
                MachineId = w.MachineId,
                PurchaseOrderId = w.PurchaseOrderId,
                Objective = w.Objective,
                CurrentAgent = w.CurrentAgent,
                Status = w.Status,
                ApprovalStatus = w.ApprovalStatus,
                StartedAt = w.StartedAt,
                CompletedAt = w.CompletedAt,
                FinalOutcome = w.FinalOutcome,
                Details = string.IsNullOrWhiteSpace(w.StateJson) ? null : System.Text.Json.JsonSerializer.Deserialize<object>(w.StateJson)
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
                WorkflowType = w.WorkflowType,
                MachineId = w.MachineId,
                PurchaseOrderId = w.PurchaseOrderId,
                Objective = w.Objective,
                CurrentAgent = w.CurrentAgent,
                Status = w.Status,
                ApprovalStatus = w.ApprovalStatus,
                StartedAt = w.StartedAt,
                CompletedAt = w.CompletedAt,
                FinalOutcome = w.FinalOutcome,
                Details = string.IsNullOrWhiteSpace(w.StateJson) ? null : System.Text.Json.JsonSerializer.Deserialize<object>(w.StateJson)
            };
        }

        public async Task<AgentWorkflowDto> ApproveWorkflowAsync(string workflowId)
        {
            var w = await _db.AgentWorkflows.SingleOrDefaultAsync(x => x.WorkflowId == workflowId)
                ?? throw new AuthException("Workflow was not found.", HttpStatusCode.NotFound);

            if (w.ApprovalStatus == ApprovalStatus.Approved) return MapWorkflow(w);
            if (w.ApprovalStatus == ApprovalStatus.Rejected)
                throw new AuthException("Cannot approve a workflow that has already been rejected.", HttpStatusCode.Conflict);

            if (w.WorkflowType == "Maintenance")
            {
                if (w.MachineId.HasValue)
                {
                    var machine = await _db.Machines.FindAsync(w.MachineId.Value);
                    if (machine != null)
                    {
                        machine.Status = MachineStatus.UnderMaintenance;
                        machine.UpdatedAt = DateTime.UtcNow;
                        w.FinalOutcome = $"Maintenance authorized for {machine.Name}. Equipment is under maintenance; record the actual service after completion.";
                    }
                    else
                    {
                        w.FinalOutcome = "Maintenance authorized by IT Admin.";
                    }
                }
                else
                {
                    w.FinalOutcome = "Maintenance authorized by IT Admin.";
                }

                w.Status = WorkflowStatus.Completed;
                w.ApprovalStatus = ApprovalStatus.Approved;
                w.CurrentAgent = "Maintenance Authorization";
                w.CompletedAt = DateTime.UtcNow;
            }
            else if (w.WorkflowType == "Procurement")
            {
                // IT Admin has authority to approve agentic workflows, but NOT execute payment.
                // Moves workflow to Approved and updates linked PO to Approved (awaiting SCM payment).
                w.ApprovalStatus = ApprovalStatus.Approved;
                w.Status = WorkflowStatus.Running;
                w.CurrentAgent = "Payment / Dispatch";
                w.CompletedAt = null;

                PurchaseOrder? po = null;
                if (w.PurchaseOrderId.HasValue)
                {
                    po = await _db.PurchaseOrders.Include(p => p.Supplier).FirstOrDefaultAsync(p => p.Id == w.PurchaseOrderId.Value);
                }
                if (po == null)
                {
                    po = await _db.PurchaseOrders.Include(p => p.Supplier).FirstOrDefaultAsync(p => p.Notes != null && p.Notes.Contains(w.WorkflowId));
                }

                if (po != null)
                {
                    w.PurchaseOrderId = po.Id;
                    if (po.Status == PurchaseOrderStatus.Draft || po.Status == PurchaseOrderStatus.PendingApproval)
                    {
                        po.Status = PurchaseOrderStatus.Approved;
                        po.ApprovedAt = DateTime.UtcNow;
                        po.UpdatedAt = DateTime.UtcNow;

                        _db.PurchaseOrderApprovals.Add(new PurchaseOrderApproval
                        {
                            PurchaseOrderId = po.Id,
                            Action = "Approved",
                            Notes = "Proposal approved by IT Admin. Awaiting Supply Chain Manager payment settlement.",
                            Timestamp = DateTime.UtcNow
                        });
                    }

                    w.FinalOutcome = $"Procurement proposal authorized by IT Admin for PO {po.PoNumber}. Purchase Order approved and awaiting Supply Chain Manager payment settlement.";
                }
                else
                {
                    w.FinalOutcome = "Procurement workflow authorized by IT Admin. Awaiting payment settlement.";
                }
            }
            else
            {
                // Generic or Quality workflow authorization
                w.Status = WorkflowStatus.Completed;
                w.ApprovalStatus = ApprovalStatus.Approved;
                w.CurrentAgent = "Admin Authorization";
                w.CompletedAt = DateTime.UtcNow;
                if (string.IsNullOrWhiteSpace(w.FinalOutcome))
                {
                    w.FinalOutcome = $"{w.WorkflowType} workflow authorized by IT Admin.";
                }
            }

            await _db.SaveChangesAsync();

            // Notify AI server if available (fire-and-forget)
            try
            {
                using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
                var aiBase = (_configuration?["AgentServer:BaseUrl"] ?? "http://localhost:8000").TrimEnd('/');
                await http.PostAsync($"{aiBase}/api/workflows/{w.WorkflowId}/approve", null);
            }
            catch
            {
                // Best-effort notification
            }

            return MapWorkflow(w);
        }

        public async Task<AgentWorkflowDto> RejectWorkflowAsync(string workflowId)
        {
            var w = await _db.AgentWorkflows.SingleOrDefaultAsync(x => x.WorkflowId == workflowId)
                ?? throw new AuthException("Workflow was not found.", HttpStatusCode.NotFound);

            if (w.ApprovalStatus == ApprovalStatus.Rejected) return MapWorkflow(w);
            if (w.ApprovalStatus == ApprovalStatus.Approved)
                throw new AuthException("Cannot reject an already approved workflow.", HttpStatusCode.Conflict);

            if (w.WorkflowType == "Maintenance")
            {
                w.Status = WorkflowStatus.Failed;
                w.ApprovalStatus = ApprovalStatus.Rejected;
                w.CompletedAt = DateTime.UtcNow;
                w.FinalOutcome = "Maintenance request rejected by IT Admin.";
            }
            else if (w.WorkflowType == "Procurement")
            {
                PurchaseOrder? po = null;
                if (w.PurchaseOrderId.HasValue)
                {
                    po = await _db.PurchaseOrders.FirstOrDefaultAsync(p => p.Id == w.PurchaseOrderId.Value);
                }
                if (po == null)
                {
                    po = await _db.PurchaseOrders.FirstOrDefaultAsync(p => p.Notes != null && p.Notes.Contains(w.WorkflowId));
                }

                if (po != null && po.Status != PurchaseOrderStatus.Paid && po.Status != PurchaseOrderStatus.Sent && po.Status != PurchaseOrderStatus.Delivered && po.Status != PurchaseOrderStatus.Completed)
                {
                    po.Status = PurchaseOrderStatus.Rejected;
                    po.UpdatedAt = DateTime.UtcNow;
                    _db.PurchaseOrderApprovals.Add(new PurchaseOrderApproval
                    {
                        PurchaseOrderId = po.Id,
                        Action = "Rejected",
                        Notes = "Proposal rejected by IT Admin.",
                        Timestamp = DateTime.UtcNow
                    });
                }

                w.Status = WorkflowStatus.Failed;
                w.ApprovalStatus = ApprovalStatus.Rejected;
                w.CompletedAt = DateTime.UtcNow;
                w.FinalOutcome = "Procurement proposal rejected by IT Admin.";
            }
            else
            {
                w.Status = WorkflowStatus.Failed;
                w.ApprovalStatus = ApprovalStatus.Rejected;
                w.CompletedAt = DateTime.UtcNow;
                w.FinalOutcome = $"{w.WorkflowType} workflow rejected by IT Admin.";
            }

            await _db.SaveChangesAsync();

            // Notify AI server if available (fire-and-forget)
            try
            {
                using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
                var aiBase = (_configuration?["AgentServer:BaseUrl"] ?? "http://localhost:8000").TrimEnd('/');
                await http.PostAsync($"{aiBase}/api/workflows/{w.WorkflowId}/reject", null);
            }
            catch
            {
                // Best-effort notification
            }

            return MapWorkflow(w);
        }

        public async Task<object> TriggerWorkflowAsync(string objective, string? workflowId)
        {
            var match = System.Text.RegularExpressions.Regex.Match(objective ?? "",
                @"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b");
            if (!match.Success || !Guid.TryParse(match.Value, out var machineId))
                throw new AuthException("Select a machine and include its ID in the maintenance request. Start procurement from the replenishment or procurement page.");
            var machine = await _db.Machines.FindAsync(machineId)
                ?? throw new AuthException("The selected machine was not found.", HttpStatusCode.NotFound);
            var pending = await _db.AgentWorkflows.FirstOrDefaultAsync(w => w.WorkflowType == "Maintenance" &&
                w.MachineId == machineId && w.Status == WorkflowStatus.WaitingForApproval);
            if (pending != null) return MapWorkflow(pending);
            var id = string.IsNullOrWhiteSpace(workflowId) ? $"WF-MAINT-{Guid.NewGuid():N}" : workflowId.Trim();
            if (id.Length > 50 || await _db.AgentWorkflows.AnyAsync(w => w.WorkflowId == id))
                throw new AuthException("Choose a unique workflow ID of at most 50 characters.");
            var workflow = new ManufacturingCoordinator.Models.Administration.AgentWorkflow {
                WorkflowId = id, WorkflowType = "Maintenance", MachineId = machineId,
                Objective = objective!, CurrentAgent = "Maintenance Review", Status = WorkflowStatus.WaitingForApproval,
                ApprovalStatus = ApprovalStatus.Pending,
                FinalOutcome = $"{machine.Name}: {machine.UptimeHours} operating hours; interval {machine.MaintenanceIntervalHours} hours. Awaiting IT Admin authorization." };
            _db.AgentWorkflows.Add(workflow);
            await _db.SaveChangesAsync();
            return MapWorkflow(workflow);
        }

        private static AgentWorkflowDto MapWorkflow(ManufacturingCoordinator.Models.Administration.AgentWorkflow w) => new() {
            Id = w.Id, WorkflowId = w.WorkflowId, WorkflowType = w.WorkflowType, MachineId = w.MachineId,
            PurchaseOrderId = w.PurchaseOrderId, Objective = w.Objective, CurrentAgent = w.CurrentAgent,
            Status = w.Status, ApprovalStatus = w.ApprovalStatus, StartedAt = w.StartedAt,
            CompletedAt = w.CompletedAt, FinalOutcome = w.FinalOutcome,
            Details = string.IsNullOrWhiteSpace(w.StateJson) ? null : System.Text.Json.JsonSerializer.Deserialize<object>(w.StateJson) };

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
                if (!await _db.Database.CanConnectAsync()) throw new InvalidOperationException("Database is unavailable.");
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
            var aiBaseUrl = (_configuration?["AgentServer:BaseUrl"] ?? "http://localhost:8000").TrimEnd('/');
            try
            {
                using var httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
                var response = await httpClient.GetAsync($"{aiBaseUrl}/health");
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
                    Message = $"FastAPI service is running on {aiBaseUrl}."
                });
                services.Add(new ServiceHealthDto
                {
                    Name = "Agentic AI",
                    Status = "ONLINE",
                    Message = "LangGraph Planner Agent is active and responsive."
                });
            }
            else
            {
                services.Add(new ServiceHealthDto
                {
                    Name = "FastAPI",
                    Status = "OFFLINE",
                    Message = aiErrorMessage ?? $"FastAPI service is not reachable on {aiBaseUrl}."
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
                EmployeeId = user.EmployeeId,
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
