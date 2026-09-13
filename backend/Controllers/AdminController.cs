using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ManufacturingCoordinator.Api.DTOs.Administration;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/admin")]
    [Authorize(Roles = "ITAdmin")]
    public class AdminController : ControllerBase
    {
        private readonly IAdminService _adminService;
        private readonly IAuditService _auditService;

        public AdminController(IAdminService adminService, IAuditService auditService)
        {
            _adminService = adminService;
            _auditService = auditService;
        }

        // ========== Users ==========

        [HttpGet("users")]
        public async Task<IActionResult> GetAllUsers()
        {
            var users = await _adminService.GetAllUsersAsync();
            return Ok(users);
        }

        [HttpGet("users/{id}")]
        public async Task<IActionResult> GetUserById(Guid id)
        {
            var user = await _adminService.GetUserByIdAsync(id);
            return Ok(user);
        }

        [HttpPost("users")]
        public async Task<IActionResult> CreateUser([FromBody] AdminCreateUserDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var user = await _adminService.CreateUserAsync(dto);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "CREATE_USER", "User", user.Id.ToString(), true, ip);

            return Ok(user);
        }

        [HttpPut("users/{id}")]
        public async Task<IActionResult> UpdateUser(Guid id, [FromBody] AdminUpdateUserDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var user = await _adminService.UpdateUserAsync(id, dto);

            // Audit log
            var currentUserId = GetCurrentUserId();
            var currentUserName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(currentUserId, currentUserName, "UPDATE_USER", "User", id.ToString(), true, ip);

            return Ok(user);
        }

        [HttpPut("users/{id}/activate")]
        public async Task<IActionResult> ActivateUser(Guid id)
        {
            await _adminService.ActivateUserAsync(id);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "ACTIVATE_USER", "User", id.ToString(), true, ip);

            return Ok(new { message = "User activated successfully." });
        }

        [HttpPut("users/{id}/deactivate")]
        public async Task<IActionResult> DeactivateUser(Guid id)
        {
            await _adminService.DeactivateUserAsync(id);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "DEACTIVATE_USER", "User", id.ToString(), true, ip);

            return Ok(new { message = "User deactivated successfully." });
        }

        [HttpPut("users/{id}/role")]
        public async Task<IActionResult> AssignRole(Guid id, [FromBody] AssignRoleDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var user = await _adminService.AssignRoleAsync(id, dto);

            // Audit log
            var currentUserId = GetCurrentUserId();
            var currentUserName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(currentUserId, currentUserName, "ASSIGN_ROLE", "User", id.ToString(), true, ip);

            return Ok(user);
        }

        // ========== Roles ==========

        [HttpGet("roles")]
        public async Task<IActionResult> GetAllRoles()
        {
            var roles = await _adminService.GetAllRolesAsync();
            return Ok(roles);
        }

        // ========== Audit Logs ==========

        [HttpGet("audit-logs")]
        public async Task<IActionResult> GetAuditLogs(
            [FromQuery] string? userName = null,
            [FromQuery] string? action = null,
            [FromQuery] string? entity = null,
            [FromQuery] DateTime? fromDate = null,
            [FromQuery] DateTime? toDate = null)
        {
            var logs = await _auditService.GetAllAsync(userName, action, entity, fromDate, toDate);
            return Ok(logs);
        }

        // ========== Agent Workflows ==========

        [HttpGet("agent-workflows")]
        public async Task<IActionResult> GetAllWorkflows()
        {
            var workflows = await _adminService.GetAllWorkflowsAsync();
            return Ok(workflows);
        }

        [HttpGet("agent-workflows/{id}")]
        public async Task<IActionResult> GetWorkflowById(Guid id)
        {
            var workflow = await _adminService.GetWorkflowByIdAsync(id);
            return Ok(workflow);
        }

        [HttpPost("agent-workflows/{workflowId}/approve")]
        public async Task<IActionResult> ApproveWorkflow(string workflowId)
        {
            var workflow = await _adminService.ApproveWorkflowAsync(workflowId);
            return Ok(workflow);
        }

        [HttpPost("agent-workflows/{workflowId}/reject")]
        public async Task<IActionResult> RejectWorkflow(string workflowId)
        {
            var workflow = await _adminService.RejectWorkflowAsync(workflowId);
            return Ok(workflow);
        }

        [HttpPost("agent-workflows/trigger")]
        public async Task<IActionResult> TriggerWorkflow([FromBody] TriggerWorkflowDto dto)
        {
            var result = await _adminService.TriggerWorkflowAsync(dto.Objective, dto.WorkflowId);
            return Ok(result);
        }

        // ========== System Health ==========

        [HttpGet("system-health")]
        public async Task<IActionResult> GetSystemHealth()
        {
            var health = await _adminService.GetSystemHealthAsync();
            return Ok(health);
        }

        // ========== Helpers ==========

        private Guid GetCurrentUserId()
        {
            var claim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier);
            return claim != null ? Guid.Parse(claim.Value) : Guid.Empty;
        }

        private string GetCurrentUserName()
        {
            return User.FindFirst(System.Security.Claims.ClaimTypes.Name)?.Value ?? "Unknown";
        }
    }
}
