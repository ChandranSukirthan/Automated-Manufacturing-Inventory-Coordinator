using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ManufacturingCoordinator.Api.DTOs.Production;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Authorize]
    public class MaintenanceController : ControllerBase
    {
        private readonly IMaintenanceService _maintenanceService;
        private readonly IAuditService _auditService;

        public MaintenanceController(IMaintenanceService maintenanceService, IAuditService auditService)
        {
            _maintenanceService = maintenanceService;
            _auditService = auditService;
        }

        [HttpGet("api/machines/{id}/maintenance")]
        public async Task<IActionResult> GetByMachine(Guid id)
        {
            var logs = await _maintenanceService.GetByMachineIdAsync(id);
            return Ok(logs);
        }

        [HttpPost("api/maintenance")]
        [Authorize(Roles = "ITAdmin")]
        public async Task<IActionResult> Create([FromBody] CreateMaintenanceLogDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var log = await _maintenanceService.CreateAsync(dto);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "CREATE", "MaintenanceLog", log.Id.ToString(), true, ip);

            return Ok(log);
        }

        [HttpPut("api/maintenance/{id}")]
        [Authorize(Roles = "ITAdmin")]
        public async Task<IActionResult> Update(Guid id, [FromBody] UpdateMaintenanceLogDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var log = await _maintenanceService.UpdateAsync(id, dto);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "UPDATE", "MaintenanceLog", id.ToString(), true, ip);

            return Ok(log);
        }

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
