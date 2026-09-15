using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.Production;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Data
{
    public static class DbInitializer
    {
        public static async Task SeedAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var passwordHasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();

            // 1. Seed Users for all roles (Upsert to ensure known credentials & verified status)
            var seedUsers = new[]
            {
                ("admin@amic.com", "System Admin", "Admin@123", UserRole.ITAdmin),
                ("worker@amic.com", "Floor Worker", "Worker@123", UserRole.FloorWorker),
                ("manager@amic.com", "Supply Chain Manager", "Manager@123", UserRole.SupplyChainManager),
                ("quality@amic.com", "Quality Inspector", "Quality@123", UserRole.QualityInspector)
            };

            foreach (var (email, name, pwd, role) in seedUsers)
            {
                var existing = await db.Users.FirstOrDefaultAsync(u => u.Email == email);
                if (existing != null)
                {
                    existing.FullName = name;
                    existing.PasswordHash = passwordHasher.HashPassword(pwd);
                    existing.Role = role;
                    existing.IsEmailVerified = true;
                    existing.IsActive = true;
                    existing.UpdatedAt = DateTime.UtcNow;
                }
                else
                {
                    db.Users.Add(new User
                    {
                        FullName = name,
                        Email = email,
                        PasswordHash = passwordHasher.HashPassword(pwd),
                        Role = role,
                        IsEmailVerified = true,
                        IsActive = true
                    });
                }
            }
            await db.SaveChangesAsync();

            // 2. Seed Machines & Maintenance Logs
            if (!await db.Machines.AnyAsync())
            {
                var cncMachine = new Machine
                {
                    Name = "CNC Milling Machine 01",
                    Status = MachineStatus.Operational,
                    UptimeHours = 480,
                    MaintenanceIntervalHours = 500,
                    Location = "Floor A - Sector 1"
                };

                var pressMachine = new Machine
                {
                    Name = "Hydraulic Press 02",
                    Status = MachineStatus.UnderMaintenance,
                    UptimeHours = 510,
                    MaintenanceIntervalHours = 500,
                    Location = "Floor B - Sector 2"
                };

                var welderMachine = new Machine
                {
                    Name = "Robotic Welder 03",
                    Status = MachineStatus.Operational,
                    UptimeHours = 120,
                    MaintenanceIntervalHours = 600,
                    Location = "Floor A - Sector 3"
                };

                var laserCutter = new Machine
                {
                    Name = "Laser Cutter 04",
                    Status = MachineStatus.Offline,
                    UptimeHours = 300,
                    MaintenanceIntervalHours = 400,
                    Location = "Floor C - Sector 1"
                };

                await db.Machines.AddRangeAsync(cncMachine, pressMachine, welderMachine, laserCutter);
                await db.SaveChangesAsync();

                // Add sample maintenance logs
                var logs = new List<MaintenanceLog>
                {
                    new MaintenanceLog
                    {
                        MachineId = cncMachine.Id,
                        Description = "Spindle bearing lubrication and thermal sensor calibration",
                        PerformedBy = "Tech Sarah Smith",
                        Type = MaintenanceType.Preventive,
                        PerformedAt = DateTime.UtcNow.AddDays(-10)
                    },
                    new MaintenanceLog
                    {
                        MachineId = pressMachine.Id,
                        Description = "Hydraulic cylinder pressure seal replacement and fluid flush",
                        PerformedBy = "Tech John Doe",
                        Type = MaintenanceType.Scheduled,
                        PerformedAt = DateTime.UtcNow.AddDays(-1)
                    },
                    new MaintenanceLog
                    {
                        MachineId = laserCutter.Id,
                        Description = "Emergency optical lens realignment after sensor fault",
                        PerformedBy = "Tech Alex Wong",
                        Type = MaintenanceType.Emergency,
                        PerformedAt = DateTime.UtcNow.AddDays(-3)
                    }
                };

                await db.MaintenanceLogs.AddRangeAsync(logs);
                await db.SaveChangesAsync();
            }

            // 3. Seed Shifts
            if (!await db.Shifts.AnyAsync())
            {
                var shifts = new List<Shift>
                {
                    new Shift
                    {
                        Name = "Shift Morning A",
                        ProductionTarget = 10000,
                        AvailableMaterial = 6000,
                        AdjustedOutput = 6000,
                        ActualOutput = 5850,
                        Status = ShiftStatus.InProgress,
                        StartTime = DateTime.UtcNow.Date.AddHours(8),
                        EndTime = DateTime.UtcNow.Date.AddHours(16)
                    },
                    new Shift
                    {
                        Name = "Shift Evening B",
                        ProductionTarget = 8000,
                        AvailableMaterial = 8500,
                        AdjustedOutput = 8000,
                        ActualOutput = 0,
                        Status = ShiftStatus.Planned,
                        StartTime = DateTime.UtcNow.Date.AddHours(16),
                        EndTime = DateTime.UtcNow.Date.AddHours(24)
                    },
                    new Shift
                    {
                        Name = "Shift Night C",
                        ProductionTarget = 5000,
                        AvailableMaterial = 5000,
                        AdjustedOutput = 5000,
                        ActualOutput = 4920,
                        Status = ShiftStatus.Completed,
                        StartTime = DateTime.UtcNow.Date.AddDays(-1).AddHours(0),
                        EndTime = DateTime.UtcNow.Date.AddDays(-1).AddHours(8)
                    }
                };

                await db.Shifts.AddRangeAsync(shifts);
                await db.SaveChangesAsync();
            }

            // 4. Seed Agent Workflows
            if (!await db.AgentWorkflows.AnyAsync())
            {
                var workflows = new List<AgentWorkflow>
                {
                    new AgentWorkflow
                    {
                        WorkflowId = "WF-1001",
                        Objective = "Optimize CNC feed rates and verify safety tolerances",
                        CurrentAgent = "Validation/Safety",
                        Status = WorkflowStatus.WaitingForApproval,
                        ApprovalStatus = ApprovalStatus.Pending,
                        StartedAt = DateTime.UtcNow.AddHours(-3),
                        FinalOutcome = null
                    },
                    new AgentWorkflow
                    {
                        WorkflowId = "WF-1002",
                        Objective = "Automated raw material procurement & PO dispatch",
                        CurrentAgent = "ProcurementAgent",
                        Status = WorkflowStatus.Completed,
                        ApprovalStatus = ApprovalStatus.Approved,
                        StartedAt = DateTime.UtcNow.AddDays(-1),
                        CompletedAt = DateTime.UtcNow.AddDays(-1).AddMinutes(45),
                        FinalOutcome = "PO-9021 issued and vendor confirmed receipt."
                    },
                    new AgentWorkflow
                    {
                        WorkflowId = "WF-1003",
                        Objective = "Anomaly detection & predictive diagnostics for Hydraulic Press 02",
                        CurrentAgent = "MaintenanceDiagnostics",
                        Status = WorkflowStatus.Running,
                        ApprovalStatus = ApprovalStatus.Pending,
                        StartedAt = DateTime.UtcNow.AddMinutes(-40),
                        FinalOutcome = null
                    }
                };

                await db.AgentWorkflows.AddRangeAsync(workflows);
                await db.SaveChangesAsync();
            }

            // 5. Seed Audit Logs
            if (!await db.AuditLogs.AnyAsync())
            {
                var auditLogs = new List<AuditLog>
                {
                    new AuditLog
                    {
                        UserId = Guid.NewGuid(),
                        UserName = "System Admin",
                        Action = "SEED_DATABASE",
                        Entity = "System",
                        EntityId = "INITIAL_SEED",
                        Success = true,
                        IpAddress = "127.0.0.1",
                        Timestamp = DateTime.UtcNow.AddMinutes(-10)
                    },
                    new AuditLog
                    {
                        UserId = Guid.NewGuid(),
                        UserName = "System Admin",
                        Action = "CREATE",
                        Entity = "Machine",
                        EntityId = "CNC-01",
                        Success = true,
                        IpAddress = "127.0.0.1",
                        Timestamp = DateTime.UtcNow.AddMinutes(-8)
                    },
                    new AuditLog
                    {
                        UserId = Guid.NewGuid(),
                        UserName = "System Admin",
                        Action = "ADJUST_OUTPUT",
                        Entity = "Shift",
                        EntityId = "Shift-Morning-A",
                        Success = true,
                        IpAddress = "127.0.0.1",
                        Timestamp = DateTime.UtcNow.AddMinutes(-5)
                    }
                };

                await db.AuditLogs.AddRangeAsync(auditLogs);
                await db.SaveChangesAsync();
            }
        }
    }
}
