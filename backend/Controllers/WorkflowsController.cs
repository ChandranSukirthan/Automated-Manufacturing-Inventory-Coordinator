using System.Net.Http.Headers;
using System.Text;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers;

[ApiController]
[Route("api/workflows")]
public sealed class WorkflowsController : ControllerBase
{
    private const string PythonWorkflowUrl = "http://127.0.0.1:8000/api/workflows/run";

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<WorkflowsController> _logger;

    public WorkflowsController(
        IHttpClientFactory httpClientFactory,
        ILogger<WorkflowsController> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
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

            using var pythonRequest = new HttpRequestMessage(HttpMethod.Post, PythonWorkflowUrl)
            {
                Content = new StringContent(requestBody, Encoding.UTF8)
            };

            pythonRequest.Content.Headers.ContentType =
                MediaTypeHeaderValue.TryParse(Request.ContentType, out var incomingContentType)
                    ? incomingContentType
                    : new MediaTypeHeaderValue("application/json");

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
}
