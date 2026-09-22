using System;
using System.Threading.Tasks;
using System.Security.Claims;
using System.Net.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using ManufacturingCoordinator.Api.DTOs.Quality;
using ManufacturingCoordinator.Api.Interfaces;
using System.Net.Http.Json;
using Microsoft.Extensions.Configuration;

namespace ManufacturingCoordinator.Api.Controllers
{
    [ApiController]
    [Route("api/defects")]
    [Authorize(Roles = "QualityInspector")]
    public class DefectReportController : ControllerBase
    {
        private readonly IDefectReportService _service;
        private readonly IQuarantineService _quarantineService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;

        public DefectReportController(
            IDefectReportService service,
            IQuarantineService quarantineService,
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration)
        {
            _service = service;
            _quarantineService = quarantineService;
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
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

            if (string.IsNullOrWhiteSpace(dto.SkuCode))
            {
                return BadRequest(new { message = "SKU code is required." });
            }

            if (string.IsNullOrWhiteSpace(dto.Description))
            {
                return BadRequest(new { message = "Description is required." });
            }

            var reportedByUserId = Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)
                ? userId
                : (Guid?)null;
            try
            {
                var created = await _service.CreateAsync(dto, reportedByUserId);
                return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
            }
            catch (DbUpdateException)
            {
                return Conflict(new { message = "The defect could not be saved because it conflicts with existing quality data." });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
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
            return Ok(created);
        }

        [HttpPost("analyze")]
        public async Task<IActionResult> Analyze([FromBody] CreateDefectReportDto dto)
        {
            if (dto == null || !ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var client = _httpClientFactory.CreateClient();
            var baseUrl = _configuration["AgentServer:BaseUrl"] ?? "http://localhost:8000";
            var payload = new
            {
                skuCode = dto.SkuCode,
                productType = dto.ProductType?.ToString(),
                severity = dto.Severity.ToString(),
                description = dto.Description,
                affectedInventory = dto.AffectedInventory
            };
            try
            {
                var response = await client.PostAsJsonAsync(
                    $"{baseUrl.TrimEnd('/')}/quality/recommendation",
                    payload);
                var content = await response.Content.ReadAsStringAsync();
                return new ContentResult
                {
                    StatusCode = (int)response.StatusCode,
                    ContentType = "application/json",
                    Content = content
                };
            }
            catch (HttpRequestException)
            {
                return StatusCode(503, new
                {
                    message = "The AI service is unavailable. Please start the AI service and try again."
                });
            }
            catch (TaskCanceledException)
            {
                return StatusCode(504, new
                {
                    message = "The AI service took too long to respond. Please try again."
                });
            }
        }
    }
}
