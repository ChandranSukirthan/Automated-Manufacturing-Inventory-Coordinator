using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Api.Services;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;
using Xunit;

namespace backend.Tests
{
    public class FloorWorkerEmployeeIdGeneratorTests
    {
        [Fact]
        public async Task AssignMissingAsync_AssignsSequentialEmpIdsInCreationOrder()
        {
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;
            await using var db = new ApplicationDbContext(options);
            var createdAt = DateTime.UtcNow;

            db.Users.AddRange(
                new User
                {
                    FullName = "First worker",
                    Email = "first@example.com",
                    Role = UserRole.FloorWorker,
                    CreatedAt = createdAt.AddMinutes(-2),
                },
                new User
                {
                    FullName = "Second worker",
                    Email = "second@example.com",
                    Role = UserRole.FloorWorker,
                    CreatedAt = createdAt.AddMinutes(-1),
                },
                new User
                {
                    FullName = "Administrator",
                    Email = "admin@example.com",
                    Role = UserRole.ITAdmin,
                    CreatedAt = createdAt,
                });
            await db.SaveChangesAsync();

            await FloorWorkerEmployeeIdGenerator.AssignMissingAsync(db);

            var workers = await db.Users
                .Where(user => user.Role == UserRole.FloorWorker)
                .OrderBy(user => user.CreatedAt)
                .ToListAsync();
            Assert.Equal(new[] { "EMP0001", "EMP0002" }, workers.Select(user => user.EmployeeId));
            Assert.Null((await db.Users.SingleAsync(user => user.Role == UserRole.ITAdmin)).EmployeeId);
            Assert.Equal("EMP0003", await FloorWorkerEmployeeIdGenerator.GetNextAsync(db));
        }
    }
}
