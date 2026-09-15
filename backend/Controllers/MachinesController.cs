using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ManufacturingCoordinator.Api.DTOs.Production;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/machines")]
    [Authorize]
    public class MachinesController : ControllerBase
    {
        private readonly IMachineService _machineService;
        private readonly IAuditService _auditService;

        public MachinesController(IMachineService machineService, IAuditService auditService)
        {
            _machineService = machineService;
            _auditService = auditService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var machines = await _machineService.GetAllAsync();
            return Ok(machines);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(Guid id)
        {
            var machine = await _machineService.GetByIdAsync(id);
            return Ok(machine);
        }

        [HttpPost]
        [Authorize(Roles = "ITAdmin")]
        public async Task<IActionResult> Create([FromBody] CreateMachineDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var machine = await _machineService.CreateAsync(dto);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "CREATE", "Machine", machine.Id.ToString(), true, ip);

            return CreatedAtAction(nameof(GetById), new { id = machine.Id }, machine);
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "ITAdmin")]
        public async Task<IActionResult> Update(Guid id, [FromBody] UpdateMachineDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var machine = await _machineService.UpdateAsync(id, dto);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "UPDATE", "Machine", id.ToString(), true, ip);

            return Ok(machine);
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "ITAdmin")]
        public async Task<IActionResult> Delete(Guid id)
        {
            await _machineService.DeleteAsync(id);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "DELETE", "Machine", id.ToString(), true, ip);

            return NoContent();
        }

        [HttpPost("{id}/calculate-maintenance")]
        public async Task<IActionResult> CalculateMaintenance(Guid id)
        {
            var result = await _machineService.CalculateMaintenanceAsync(id);
            return Ok(result);
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
