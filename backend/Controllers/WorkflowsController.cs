using System.Net.Http.Headers;
using System.Text;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers;

[ApiController]
[Route("api/workflows")]
[Microsoft.AspNetCore.Authorization.Authorize(Roles = "FloorWorker,SupplyChainManager,ITAdmin")]
public sealed class WorkflowsController : ControllerBase
{
    private readonly string _pythonBaseUrl;

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<WorkflowsController> _logger;

    public WorkflowsController(
        IHttpClientFactory httpClientFactory,
        ILogger<WorkflowsController> logger, IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
        _pythonBaseUrl = (configuration["AgentServer:BaseUrl"] ?? "http://127.0.0.1:8000").TrimEnd('/');
    }

    // POST: api/workflows/run
    // Receives the mobile request and proxies it to the Python AI service.
    [HttpPost("run")]
    public async Task<IActionResult> Run(CancellationToken cancellationToken)
    {
        try
        {
            using var reader = new StreamReader(Request.Body);
            var requestBody = await reader.ReadToEndAsync(cancellationToken);

            using var pythonRequest = new HttpRequestMessage(HttpMethod.Post, $"{_pythonBaseUrl}/api/workflows/run")
            {
                Content = new StringContent(requestBody, Encoding.UTF8)
            };

            pythonRequest.Content.Headers.ContentType =
                MediaTypeHeaderValue.TryParse(Request.ContentType, out var incomingContentType)
                    ? incomingContentType
                    : new MediaTypeHeaderValue("application/json");

            if (Request.Headers.TryGetValue("Authorization", out var authorization))
                pythonRequest.Headers.TryAddWithoutValidation("Authorization", authorization.ToString());
            var httpClient = _httpClientFactory.CreateClient();
            using var pythonResponse = await httpClient.SendAsync(
                pythonRequest,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);

            var responseBody = await pythonResponse.Content.ReadAsStringAsync(cancellationToken);
            var responseContentType = pythonResponse.Content.Headers.ContentType?.ToString()
                ?? "application/json";

            return new ContentResult
            {
                StatusCode = (int)pythonResponse.StatusCode,
                ContentType = responseContentType,
                Content = responseBody
            };
        }
        catch (HttpRequestException exception)
        {
            _logger.LogError(exception, "The Python AI workflow service could not be reached.");
            return Problem(
                title: "The Python AI workflow service is unavailable.",
                statusCode: StatusCodes.Status502BadGateway);
        }
    }

    [HttpPost("{workflowId}/retry")]
    public async Task<IActionResult> Retry(string workflowId,
        [FromServices] ManufacturingCoordinator.Data.ApplicationDbContext db,
        CancellationToken cancellationToken)
    {
        var workflow = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.SingleOrDefaultAsync(
            db.AgentWorkflows, w => w.WorkflowId == workflowId, cancellationToken);
        if (workflow == null) return NotFound(new { message = "Workflow was not found." });
        if (workflow.PurchaseOrderId.HasValue) return Conflict(new { message = "Update the linked order instead of generating another draft." });
        using var request = new HttpRequestMessage(HttpMethod.Post,
            $"{_pythonBaseUrl}/api/workflows/{Uri.EscapeDataString(workflowId)}/retry");
        request.Headers.TryAddWithoutValidation("Authorization", Request.Headers.Authorization.ToString());
        try
        {
            using var response = await _httpClientFactory.CreateClient().SendAsync(request, cancellationToken);
            return new ContentResult { StatusCode = (int)response.StatusCode, ContentType = "application/json",
                Content = await response.Content.ReadAsStringAsync(cancellationToken) };
        }
        catch (HttpRequestException)
        {
            return Problem(title: "The AI service is unavailable. Manual CRUD remains available.", statusCode: 502);
        }
    }
}
