using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Api.DTOs.Administration;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Models.Administration;

namespace ManufacturingCoordinator.Api.Services
{
    public class AuditService : IAuditService
    {
        private readonly ApplicationDbContext _db;

        public AuditService(ApplicationDbContext db)
        {
            _db = db;
        }

        public async Task LogAsync(Guid userId, string userName, string action, string entity, string entityId, bool success, string? ipAddress = null)
        {
            var auditLog = new AuditLog
            {
                UserId = userId,
                UserName = userName,
                Action = action,
                Entity = entity,
                EntityId = entityId,
                Success = success,
                IpAddress = ipAddress,
                Timestamp = DateTime.UtcNow
            };

            _db.AuditLogs.Add(auditLog);
            await _db.SaveChangesAsync();
        }

        public async Task<List<AuditLogDto>> GetAllAsync(string? userName = null, string? action = null, string? entity = null, DateTime? fromDate = null, DateTime? toDate = null)
        {
            var query = _db.AuditLogs.AsQueryable();

            if (!string.IsNullOrWhiteSpace(userName))
                query = query.Where(a => a.UserName.ToLower().Contains(userName.ToLower()));

            if (!string.IsNullOrWhiteSpace(action))
                query = query.Where(a => a.Action.ToLower().Contains(action.ToLower()));

            if (!string.IsNullOrWhiteSpace(entity))
                query = query.Where(a => a.Entity.ToLower().Contains(entity.ToLower()));

            if (fromDate.HasValue)
            {
                var utcFrom = DateTime.SpecifyKind(fromDate.Value, DateTimeKind.Utc);
                query = query.Where(a => a.Timestamp >= utcFrom);
            }

            if (toDate.HasValue)
            {
                var utcTo = DateTime.SpecifyKind(toDate.Value, DateTimeKind.Utc);
                var endOfToDate = utcTo.TimeOfDay == TimeSpan.Zero
                    ? utcTo.Date.AddDays(1).AddTicks(-1)
                    : utcTo;
                query = query.Where(a => a.Timestamp <= endOfToDate);
            }

            var logs = await query
                .OrderByDescending(a => a.Timestamp)
                .Take(500) // Limit to prevent huge responses
                .ToListAsync();

            return logs.Select(a => new AuditLogDto
            {
                Id = a.Id,
                UserId = a.UserId,
                UserName = a.UserName,
                Action = a.Action,
                Entity = a.Entity,
                EntityId = a.EntityId,
                Timestamp = a.Timestamp,
                Success = a.Success,
                IpAddress = a.IpAddress
            }).ToList();
        }
    }
}
