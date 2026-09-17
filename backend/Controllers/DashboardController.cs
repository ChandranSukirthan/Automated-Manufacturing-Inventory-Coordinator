using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize] // This protects all endpoints in this controller by default
    public class DashboardController : ControllerBase
    {
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

        [HttpGet("admin")]
        [Authorize(Roles = "ITAdmin")]
        public IActionResult GetAdminData()
        {
            return Ok(new { message = "Welcome to the IT Admin Dashboard!" });
        }
    }
}
