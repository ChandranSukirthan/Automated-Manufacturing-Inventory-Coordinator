using System.Net;
using System.Text.Json;
using ManufacturingCoordinator.Api.Helpers;

namespace ManufacturingCoordinator.Api.Middleware
{
    public class ExceptionMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<ExceptionMiddleware> _logger;

        public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (AuthException ex)
            {
                context.Response.ContentType = "application/json";
                context.Response.StatusCode = (int)ex.StatusCode;

                var result = JsonSerializer.Serialize(new { message = ex.Message });
                await context.Response.WriteAsync(result);
            }
            catch (Microsoft.EntityFrameworkCore.DbUpdateConcurrencyException)
            {
                context.Response.StatusCode = 409;
                await context.Response.WriteAsJsonAsync(new { message = "This record changed concurrently. Refresh and retry." });
            }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException ex)
            {
                _logger.LogWarning(ex, "Database rejected a conflicting operation.");
                context.Response.StatusCode = 409;
                await context.Response.WriteAsJsonAsync(new { message = "This record conflicts with existing data or has linked history. Refresh and check the values." });
            }
            catch (KeyNotFoundException ex)
            {
                context.Response.StatusCode = 404;
                await context.Response.WriteAsJsonAsync(new { message = ex.Message });
            }
            catch (Exception ex) when (ex is ArgumentException or InvalidOperationException)
            {
                context.Response.StatusCode = 400;
                await context.Response.WriteAsJsonAsync(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An unhandled exception occurred.");

                context.Response.ContentType = "application/json";
                context.Response.StatusCode = (int)HttpStatusCode.InternalServerError;

                var result = JsonSerializer.Serialize(new { message = "An internal server error occurred." });
                await context.Response.WriteAsync(result);
            }
        }
    }
}
