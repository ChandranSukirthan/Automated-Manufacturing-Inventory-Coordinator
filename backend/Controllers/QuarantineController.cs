using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/quarantine")]
    [Authorize(Roles = "QualityInspector,SupplyChainManager,ITAdmin")]
    public class QuarantineController : ControllerBase
    {
        private readonly IQuarantineService _service;

        public QuarantineController(IQuarantineService service)
        {
            _service = service;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            return Ok(await _service.GetAllAsync());
        }

        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetById(Guid id)
        {
            var quarantine = await _service.GetByIdAsync(id);
            return quarantine == null ? NotFound() : Ok(quarantine);
        }

        [HttpPost("{id:guid}/release")]
        [Authorize(Roles = "QualityInspector")]
        public async Task<IActionResult> Release(Guid id, [FromBody] ReleaseQuarantineDto? dto = null)
        {
            var resolvedBy = User.Identity?.Name ?? "QualityInspector";
            var quarantine = await _service.ReleaseAsync(id, dto?.ResolutionNote, resolvedBy);
            return quarantine == null ? NotFound() : Ok(quarantine);
        }

        [HttpPost("defect/{defectId:guid}/release-all")]
        [Authorize(Roles = "QualityInspector")]
        public async Task<IActionResult> ReleaseAllForDefect(Guid defectId, [FromBody] ReleaseQuarantineDto? dto = null)
        {
            var resolvedBy = User.Identity?.Name ?? "QualityInspector";
            var released = await _service.ReleaseAllForDefectAsync(defectId, dto?.ResolutionNote, resolvedBy);
            return Ok(released);
        }
    }
}
