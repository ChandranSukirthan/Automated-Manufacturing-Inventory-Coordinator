using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize] // This protects all endpoints in this controller by default
    public class DashboardController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public DashboardController(ApplicationDbContext db)
        {
            _db = db;
        }

        [HttpGet("worker")]
        [Authorize(Roles = "FloorWorker")]
        public IActionResult GetWorkerData()
        {
            return Ok(new { message = "Welcome to the Floor Worker Dashboard!" });
        }

        [HttpGet("manager")]
        [Authorize(Roles = "SupplyChainManager")]
        public IActionResult GetManagerData()
        {
            return Ok(new { message = "Welcome to the Supply Chain Manager Dashboard!" });
        }

        [HttpGet("quality")]
        [Authorize(Roles = "QualityInspector")]
        public IActionResult GetQualityData()
        {
            return Ok(new { message = "Welcome to the Quality Inspector Dashboard!" });
        }

        [HttpGet("quality/summary")]
        [Authorize(Roles = "QualityInspector")]
        public async Task<ActionResult<QualityDashboardSummaryDto>> GetQualitySummary()
        {
            return Ok(new QualityDashboardSummaryDto
            {
                TotalDefects = await _db.DefectReports.CountAsync(),
                HighSeverityDefects = await _db.DefectReports.CountAsync(d => d.Severity == DefectSeverity.HIGH),
                ActiveQuarantines = await _db.Quarantines.CountAsync(q => q.Status == QuarantineStatus.Active),
                ReleasedQuarantines = await _db.Quarantines.CountAsync(q => q.Status == QuarantineStatus.Released)
            });
        }

        [HttpGet("admin")]
        [Authorize(Roles = "ITAdmin")]
        public IActionResult GetAdminData()
        {
            return Ok(new { message = "Welcome to the IT Admin Dashboard!" });
        }
    }
}
