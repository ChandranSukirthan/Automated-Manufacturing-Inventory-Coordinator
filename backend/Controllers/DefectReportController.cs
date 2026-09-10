using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/defects")]
    [Authorize(Roles = "QualityInspector")]
    public class DefectReportController : ControllerBase
    {
        private readonly IDefectReportService _service;
        private readonly IQuarantineService _quarantineService;

        public DefectReportController(IDefectReportService service, IQuarantineService quarantineService)
        {
            _service = service;
            _quarantineService = quarantineService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var defects = await _service.GetAllAsync();
            return Ok(defects);
        }

        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetById(Guid id)
        {
            var defect = await _service.GetByIdAsync(id);
            if (defect == null)
            {
                return NotFound();
            }

            return Ok(defect);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateDefectReportDto dto)
        {
            if (dto == null)
            {
                return BadRequest(new { message = "The defect payload is required." });
            }

            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            if (string.IsNullOrWhiteSpace(dto.BatchId))
            {
                return BadRequest(new { message = "Batch ID is required." });
            }

            if (string.IsNullOrWhiteSpace(dto.Description))
            {
                return BadRequest(new { message = "Description is required." });
            }

            var created = await _service.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> Update(Guid id, [FromBody] UpdateDefectReportDto dto)
        {
            if (dto == null)
            {
                return BadRequest(new { message = "The defect payload is required." });
            }

            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var updated = await _service.UpdateAsync(id, dto);
            if (updated == null)
            {
                return NotFound();
            }

            return Ok(updated);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> Delete(Guid id)
        {
            var deleted = await _service.DeleteAsync(id);
            if (!deleted)
            {
                return NotFound();
            }

            return NoContent();
        }

        [HttpPost("{id:guid}/quarantine")]
        public async Task<IActionResult> Quarantine(
            Guid id,
            [FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)] CreateQuarantineDto? dto)
        {
            var created = await _quarantineService.QuarantineDefectAsync(
                id,
                dto ?? new CreateQuarantineDto());
            return CreatedAtAction(
                nameof(QuarantineController.GetById),
                "Quarantine",
                new { id = created.Id },
                created);
        }
    }
}
