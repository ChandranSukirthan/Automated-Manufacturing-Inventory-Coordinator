using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Administration;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IAuditService
    {
        Task LogAsync(Guid userId, string userName, string action, string entity, string entityId, bool success, string? ipAddress = null);
        Task<List<AuditLogDto>> GetAllAsync(string? userName = null, string? action = null, string? entity = null, DateTime? fromDate = null, DateTime? toDate = null);
    }
}
