using System.Net;

namespace ManufacturingCoordinator.Api.Helpers
{
    public class AuthException : Exception
    {
        public HttpStatusCode StatusCode { get; }

        public AuthException(string message, HttpStatusCode statusCode = HttpStatusCode.BadRequest)
            : base(message)
        {
            StatusCode = statusCode;
        }
    }
}