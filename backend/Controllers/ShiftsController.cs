using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ManufacturingCoordinator.Api.DTOs.Production;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/shifts")]
    [Authorize]
    public class ShiftsController : ControllerBase
    {
        private readonly IShiftService _shiftService;
        private readonly IAuditService _auditService;

        public ShiftsController(IShiftService shiftService, IAuditService auditService)
        {
            _shiftService = shiftService;
            _auditService = auditService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var shifts = await _shiftService.GetAllAsync();
            return Ok(shifts);
        }

        [HttpPost]
        [Authorize(Roles = "ITAdmin")]
        public async Task<IActionResult> Create([FromBody] CreateShiftDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var shift = await _shiftService.CreateAsync(dto);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "CREATE", "Shift", shift.Id.ToString(), true, ip);

            return Ok(shift);
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "ITAdmin")]
        public async Task<IActionResult> Update(Guid id, [FromBody] UpdateShiftDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var shift = await _shiftService.UpdateAsync(id, dto);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "UPDATE", "Shift", id.ToString(), true, ip);

            return Ok(shift);
        }

        [HttpPost("{id}/adjust-output")]
        [Authorize(Roles = "ITAdmin")]
        public async Task<IActionResult> AdjustOutput(Guid id)
        {
            var result = await _shiftService.AdjustOutputAsync(id);

            // Audit log
            var userId = GetCurrentUserId();
            var userName = GetCurrentUserName();
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            await _auditService.LogAsync(userId, userName, "ADJUST_OUTPUT", "Shift", id.ToString(), true, ip);

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
