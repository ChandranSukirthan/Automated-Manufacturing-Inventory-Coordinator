using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;

namespace ManufacturingCoordinator.Api.Services
{
    public static class FloorWorkerEmployeeIdGenerator
    {
        private const string Prefix = "EMP";

        public static async Task<string> GetNextAsync(ApplicationDbContext db)
        {
            var employeeIds = await db.Users
                .Where(user => user.Role == UserRole.FloorWorker && user.EmployeeId != null)
                .Select(user => user.EmployeeId!)
                .ToListAsync();

            var highestAssignedNumber = employeeIds
                .Select(ParseNumber)
                .DefaultIfEmpty(0)
                .Max();

            return Format(highestAssignedNumber + 1);
        }

        public static async Task AssignMissingAsync(ApplicationDbContext db)
        {
            var floorWorkers = await db.Users
                .Where(user => user.Role == UserRole.FloorWorker)
                .OrderBy(user => user.CreatedAt)
                .ThenBy(user => user.Id)
                .ToListAsync();

            var nextNumber = floorWorkers
                .Where(user => !string.IsNullOrWhiteSpace(user.EmployeeId))
                .Select(user => ParseNumber(user.EmployeeId!))
                .DefaultIfEmpty(0)
                .Max() + 1;

            foreach (var worker in floorWorkers.Where(user => string.IsNullOrWhiteSpace(user.EmployeeId)))
            {
                worker.EmployeeId = Format(nextNumber++);
            }

            if (db.ChangeTracker.HasChanges())
            {
                await db.SaveChangesAsync();
            }
        }

        private static int ParseNumber(string employeeId)
        {
            if (!employeeId.StartsWith(Prefix, StringComparison.OrdinalIgnoreCase)) return 0;
            return int.TryParse(employeeId[Prefix.Length..], out var number) ? number : 0;
        }

        private static string Format(int number) => $"{Prefix}{number:D4}";
    }
}
