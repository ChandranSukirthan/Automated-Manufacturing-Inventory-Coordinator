using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Models.Production;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Models.Inventory;
using ManufacturingCoordinator.Models.Quality;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Api.Services;
using RawMaterial = backend.Models.RawMaterial;

namespace ManufacturingCoordinator.Data
{
    public static class DbInitializer
    {
        public static async Task SeedAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var mfgDb = scope.ServiceProvider.GetRequiredService<backend.Data.ManufacturingContext>();
            var passwordHasher = scope.ServiceProvider.GetService<IPasswordHasher>();

            // 1. Seed roles. The verified development worker avoids an email-OTP
            // dependency during local testing; registered Floor Workers start at EMP0001.
            var seedUsers = new[]
            {
                ("admin@amic.com", "System Admin", "Admin@123", UserRole.ITAdmin),
                ("manager@amic.com", "Supply Chain Manager", "Manager@123", UserRole.SupplyChainManager),
                ("quality@amic.com", "Quality Inspector", "Quality@123", UserRole.QualityInspector),
                ("worker@amic.com", "Floor Worker", "Worker@123", UserRole.FloorWorker)
            };

            foreach (var (email, name, pwd, role) in seedUsers)
            {
                var existing = await db.Users.FirstOrDefaultAsync(u => u.Email == email);
                var hash = passwordHasher != null ? passwordHasher.HashPassword(pwd) : pwd;
                if (existing != null)
                {
                    existing.FullName = name;
                    if (passwordHasher != null) existing.PasswordHash = hash;
                    existing.Role = role;
                    existing.IsEmailVerified = true;
                    existing.IsActive = true;
                    if (role == UserRole.FloorWorker)
                    {
                        existing.EmployeeId = "EMP0000";
                    }
                    existing.UpdatedAt = DateTime.UtcNow;
                }
                else
                {
                    db.Users.Add(new User
                    {
                        FullName = name,
                        Email = email,
                        PasswordHash = hash,
                        Role = role,
                        EmployeeId = role == UserRole.FloorWorker ? "EMP0000" : null,
                        IsEmailVerified = true,
                        IsActive = true
                    });
                }
            }
            await db.SaveChangesAsync();

            await FloorWorkerEmployeeIdGenerator.AssignMissingAsync(db);

            await EnsureProcurementTablesAsync(db);
            await SeedEntitiesAsync(db, mfgDb);
        }

        public static async Task SeedAsync(ApplicationDbContext context)
        {
            await SeedEntitiesAsync(context);
        }

        private static async Task SeedEntitiesAsync(ApplicationDbContext db, backend.Data.ManufacturingContext? mfgDb = null)
        {
            await EnsureProcurementTablesAsync(db);
            // 2. Seed RawMaterials
            if (!await db.RawMaterials.AnyAsync())
            {
                var materials = new List<RawMaterial>
                {
                    new()
                    {
                        Name = "Cold Rolled Steel Sheet",
                        SkuCode = "RM-STEEL-001",
                        Category = "Metal",
                        UnitOfMeasure = "KG",
                        Description = "1.5mm standard structural steel sheet",
                        ReorderThreshold = 200m,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    },
                    new()
                    {
                        Name = "High-Tensile Aluminum Rod",
                        SkuCode = "RM-ALUM-002",
                        Category = "Metal",
                        UnitOfMeasure = "METRES",
                        Description = "6061-T6 aviation grade aluminum rod",
                        ReorderThreshold = 100m,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    },
                    new()
                    {
                        Name = "Industrial Polypropylene Pellets",
                        SkuCode = "RM-POLY-003",
                        Category = "Polymer",
                        UnitOfMeasure = "KG",
                        Description = "High-impact injection molding grade polymer",
                        ReorderThreshold = 1000m,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    }
                };

                db.RawMaterials.AddRange(materials);
                await db.SaveChangesAsync();
            }

            // 3. Seed Suppliers
            if (!await db.Suppliers.AnyAsync())
            {
                var suppliers = new List<Supplier>
                {
                    new()
                    {
                        SupplierCode = "SUP-001",
                        Name = "Lanka Flexible Packaging Supplies",
                        ContactEmail = "orders@lankaflexible.example",
                        ContactPhone = "+1-555-0192",
                        Address = "Colombo Export Processing Zone, Sri Lanka",
                        PaymentTerms = "Net 30",
                        LeadTimeDays = 7,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow.AddDays(-60),
                        UpdatedAt = DateTime.UtcNow.AddDays(-60)
                    },
                    new()
                    {
                        SupplierCode = "SUP-002",
                        Name = "Ceylon Food-Pack Materials",
                        ContactEmail = "procurement@ceylonfoodpack.example",
                        ContactPhone = "+1-555-0283",
                        Address = "Colombo Logistics Park, Sri Lanka",
                        PaymentTerms = "Net 60",
                        LeadTimeDays = 14,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow.AddDays(-45),
                        UpdatedAt = DateTime.UtcNow.AddDays(-45)
                    },
                    new()
                    {
                        SupplierCode = "SUP-003",
                        Name = "Island Polymer & Paper Mills",
                        ContactEmail = "sales@islandpolymer.example",
                        ContactPhone = "+1-555-0374",
                        Address = "Kelaniya Industrial Estate, Sri Lanka",
                        PaymentTerms = "Net 30",
                        LeadTimeDays = 10,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow.AddDays(-30),
                        UpdatedAt = DateTime.UtcNow.AddDays(-30)
                    }
                };

                db.Suppliers.AddRange(suppliers);
                await db.SaveChangesAsync();
            }

            // 4. Seed Purchase Orders with Order Lines if none exist
            if (!await db.PurchaseOrders.AnyAsync())
            {
                var supplier1 = await db.Suppliers.FirstOrDefaultAsync(s => s.SupplierCode == "SUP-001");
                var supplier2 = await db.Suppliers.FirstOrDefaultAsync(s => s.SupplierCode == "SUP-002");
                var material1 = await db.RawMaterials.FirstOrDefaultAsync();

                if (supplier1 != null && material1 != null)
                {
                    var po1 = new PurchaseOrder
                    {
                        PoNumber = "PO-2026-0001",
                        SupplierId = supplier1.Id,
                        Currency = "USD",
                        Status = PurchaseOrderStatus.Sent,
                        BudgetLimit = 10000m,
                        ApprovalThreshold = 5000m,
                        RequiresApproval = true,
                        TotalCost = 6750m,
                        Notes = "Packaging-material replenishment order",
                        StripePaymentIntentId = "pi_mock_seed_001",
                        StripePaymentStatus = "succeeded",
                        EmailStatus = "Sent",
                        EmailSentAt = DateTime.UtcNow.AddDays(-10),
                        CreatedAt = DateTime.UtcNow.AddDays(-15),
                        UpdatedAt = DateTime.UtcNow.AddDays(-10),
                        OrderLines = new List<OrderLine>
                        {
                            new()
                            {
                                RawMaterialId = material1.Id,
                                Description = "Laminated barrier film replenishment",
                                Quantity = 1500m,
                                UnitPrice = 4.50m,
                                TotalPrice = 6750m,
                                CreatedAt = DateTime.UtcNow.AddDays(-15),
                                UpdatedAt = DateTime.UtcNow.AddDays(-15)
                            }
                        }
                    };

                    db.PurchaseOrders.Add(po1);
                    await db.SaveChangesAsync();

                    db.PurchaseOrderApprovals.Add(new PurchaseOrderApproval
                    {
                        PurchaseOrderId = po1.Id,
                        Action = "PO approved",
                        UserName = "Supply Chain Manager",
                        Notes = "Approved initial stock order",
                        Timestamp = DateTime.UtcNow.AddDays(-10)
                    });

                    db.PaymentTransactions.Add(new PaymentTransaction
                    {
                        PurchaseOrderId = po1.Id,
                        TransactionId = "pi_mock_seed_001",
                        Amount = 6750m,
                        Currency = "usd",
                        PaymentStatus = "succeeded",
                        Timestamp = DateTime.UtcNow.AddDays(-10)
                    });

                    await db.SaveChangesAsync();
                }

                if (supplier2 != null && material1 != null)
                {
                    var po2 = new PurchaseOrder
                    {
                        PoNumber = "PO-2026-0002",
                        SupplierId = supplier2.Id,
                        Currency = "USD",
                        Status = PurchaseOrderStatus.PendingApproval,
                        BudgetLimit = 15000m,
                        ApprovalThreshold = 5000m,
                        RequiresApproval = true,
                        TotalCost = 9000m,
                        Notes = "AI Recommended: high burn rate forecast requires urgent packaging material replenishment.",
                        CreatedAt = DateTime.UtcNow.AddHours(-2),
                        UpdatedAt = DateTime.UtcNow.AddHours(-1),
                        OrderLines = new List<OrderLine>
                        {
                            new()
                            {
                                RawMaterialId = material1.Id,
                                Description = "High-volume flexible packaging material replenishment",
                                Quantity = 2000m,
                                UnitPrice = 4.50m,
                                TotalPrice = 9000m,
                                CreatedAt = DateTime.UtcNow.AddHours(-2),
                                UpdatedAt = DateTime.UtcNow.AddHours(-2)
                            }
                        }
                    };

                    db.PurchaseOrders.Add(po2);
                    await db.SaveChangesAsync();

                    db.PurchaseOrderApprovals.Add(new PurchaseOrderApproval
                    {
                        PurchaseOrderId = po2.Id,
                        Action = "PO submitted",
                        UserName = "System Auto-Coordinator",
                        Notes = "Submitted by AI inventory monitoring service",
                        Timestamp = DateTime.UtcNow.AddHours(-1)
                    });

                    await db.SaveChangesAsync();
                }
            }

            // 5. Seed Machines & Maintenance Logs
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

                var logs = new List<MaintenanceLog>
                {
                    new MaintenanceLog
                    {
                        MachineId = pressMachine.Id,
                        Description = "Hydraulic seal replacement and fluid flush",
                        PerformedBy = "Senior Tech - John D.",
                        Type = MaintenanceType.Emergency,
                        PerformedAt = DateTime.UtcNow.AddHours(-6)
                    },
                    new MaintenanceLog
                    {
                        MachineId = cncMachine.Id,
                        Description = "Spindle lubrication and calibration verification",
                        PerformedBy = "Tech - Sarah M.",
                        Type = MaintenanceType.Preventive,
                        PerformedAt = DateTime.UtcNow.AddDays(-3)
                    }
                };

                await db.MaintenanceLogs.AddRangeAsync(logs);
                await db.SaveChangesAsync();
            }

            // 6. Seed Shifts
            if (!await db.Shifts.AnyAsync())
            {
                var shifts = new List<Shift>
                {
                    new Shift
                    {
                        Name = "Morning Production Shift A",
                        ProductionTarget = 1500,
                        AvailableMaterial = 1400,
                        AdjustedOutput = 1350,
                        ActualOutput = 1320,
                        Status = ShiftStatus.Completed,
                        StartTime = DateTime.UtcNow.Date.AddHours(6),
                        EndTime = DateTime.UtcNow.Date.AddHours(14)
                    },
                    new Shift
                    {
                        Name = "Afternoon Production Shift B",
                        ProductionTarget = 1800,
                        AvailableMaterial = 1900,
                        AdjustedOutput = 1800,
                        ActualOutput = 950,
                        Status = ShiftStatus.InProgress,
                        StartTime = DateTime.UtcNow.Date.AddHours(14),
                        EndTime = DateTime.UtcNow.Date.AddHours(22)
                    },
                    new Shift
                    {
                        Name = "Night Maintenance & Output Shift C",
                        ProductionTarget = 1000,
                        AvailableMaterial = 1200,
                        AdjustedOutput = 1000,
                        ActualOutput = 0,
                        Status = ShiftStatus.Planned,
                        StartTime = DateTime.UtcNow.Date.AddHours(22),
                        EndTime = DateTime.UtcNow.Date.AddDays(1).AddHours(6)
                    }
                };

                await db.Shifts.AddRangeAsync(shifts);
                await db.SaveChangesAsync();
            }

            // 7. Seed Agent Workflows
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

            // 8. Seed Audit Logs
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

            // 9. Seed Batches, InventoryRolls, DefectReports & Quarantines
            if (!await db.Batches.AnyAsync())
            {
                var batch1 = new Batch
                {
                    Id = "BATCH001",
                    ProductType = ProductType.BoxPouch
                };

                var batch2 = new Batch
                {
                    Id = "BATCH002",
                    ProductType = ProductType.BiscuitPackaging
                };

                var batch3 = new Batch
                {
                    Id = "BATCH003",
                    ProductType = ProductType.TeaBag
                };

                await db.Batches.AddRangeAsync(batch1, batch2, batch3);
                await db.SaveChangesAsync();

                var roll1 = new InventoryRoll
                {
                    Id = "ROLL-001",
                    BatchId = batch1.Id,
                    Status = InventoryStatus.Available
                };

                var roll2 = new InventoryRoll
                {
                    Id = "ROLL-002",
                    BatchId = batch1.Id,
                    Status = InventoryStatus.Quarantined
                };

                var roll3 = new InventoryRoll
                {
                    Id = "ROLL-003",
                    BatchId = batch2.Id,
                    Status = InventoryStatus.Available
                };

                var roll4 = new InventoryRoll
                {
                    Id = "ROLL-004",
                    BatchId = batch2.Id,
                    Status = InventoryStatus.Available
                };

                var roll5 = new InventoryRoll
                {
                    Id = "ROLL-005",
                    BatchId = batch3.Id,
                    Status = InventoryStatus.Available
                };

                await db.InventoryRolls.AddRangeAsync(roll1, roll2, roll3, roll4, roll5);
                await db.SaveChangesAsync();

                var qualityUser = await db.Users.FirstOrDefaultAsync(u => u.Email == "quality@amic.com");

                var defect1 = new DefectReport
                {
                    BatchId = batch1.Id,
                    ProductType = ProductType.BoxPouch,
                    Severity = DefectSeverity.HIGH,
                    Description = "Edge sealing delamination and micro-perforations observed along roll perimeter.",
                    Status = DefectStatus.Open,
                    ReportedByUserId = qualityUser?.Id,
                    CreatedAt = DateTime.UtcNow.AddDays(-2)
                };

                var defect2 = new DefectReport
                {
                    BatchId = batch2.Id,
                    ProductType = ProductType.BiscuitPackaging,
                    Severity = DefectSeverity.MEDIUM,
                    Description = "Color misalignment and minor ink smudging on secondary packaging film.",
                    Status = DefectStatus.InReview,
                    ReportedByUserId = qualityUser?.Id,
                    CreatedAt = DateTime.UtcNow.AddDays(-1)
                };

                await db.DefectReports.AddRangeAsync(defect1, defect2);
                await db.SaveChangesAsync();

                var quarantine1 = new Quarantine
                {
                    DefectReportId = defect1.Id,
                    InventoryRollId = roll2.Id,
                    Reason = "Roll quarantined due to severe delamination risk on sealing line.",
                    Status = QuarantineStatus.Active,
                    CreatedAt = DateTime.UtcNow.AddDays(-1),
                    ReleasedAt = null
                };

                var quarantine2 = new Quarantine
                {
                    DefectReportId = defect2.Id,
                    InventoryRollId = roll3.Id,
                    Reason = "Temporary hold for ink smear inspection. Batch cleared after lab chromatography test.",
                    Status = QuarantineStatus.Released,
                    CreatedAt = DateTime.UtcNow.AddDays(-4),
                    ReleasedAt = DateTime.UtcNow.AddDays(-3)
                };

                await db.Quarantines.AddRangeAsync(quarantine1, quarantine2);
                await db.SaveChangesAsync();
            }

            // Ensure Iron raw material exists in ApplicationDbContext
            var ironMat = await db.RawMaterials.FirstOrDefaultAsync(m => m.SkuCode == "RM-IRON-001" || m.Name.Contains("Iron"));
            if (ironMat == null)
            {
                ironMat = new RawMaterial
                {
                    Name = "Industrial Raw Iron",
                    SkuCode = "RM-IRON-001",
                    Category = "Metal",
                    UnitOfMeasure = "KG",
                    Description = "Standard grade structural raw iron rolls",
                    ReorderThreshold = 300m,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };
                db.RawMaterials.Add(ironMat);
                await db.SaveChangesAsync();
            }

            // Ensure Batches exist in ApplicationDbContext
            var ironBatch = await db.Batches.FirstOrDefaultAsync(b => b.Id == "BATCH-IRON-001");
            if (ironBatch == null)
            {
                db.Batches.Add(new Batch { Id = "BATCH-IRON-001", ProductType = ProductType.Can });
                await db.SaveChangesAsync();
            }

            // Ensure mfgDb has Iron and historical roll if mfgDb is available
            if (mfgDb != null)
            {
                var mfgIron = await mfgDb.RawMaterials.FirstOrDefaultAsync(m => m.SkuCode == "RM-IRON-001" || m.Name.Contains("Iron"));
                if (mfgIron == null)
                {
                    mfgIron = new backend.Models.RawMaterial
                    {
                        Name = "Industrial Raw Iron",
                        SkuCode = "RM-IRON-001",
                        UnitOfMeasure = "KG",
                        Category = "Metal",
                        Description = "Standard grade structural raw iron rolls",
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    };
                    mfgDb.RawMaterials.Add(mfgIron);
                    await mfgDb.SaveChangesAsync();
                }

                var ironRoll = await mfgDb.InventoryRolls.FirstOrDefaultAsync(r => r.RollIdentifier == "IRON-ROLL-001");
                if (ironRoll == null)
                {
                    ironRoll = new backend.Models.InventoryRoll
                    {
                        RollIdentifier = "IRON-ROLL-001",
                        BatchId = "BATCH-IRON-001",
                        RawMaterialId = mfgIron.Id,
                        InitialQuantity = 2000m,
                        CurrentQuantity = 1800m,
                        Status = "Available",
                        BarcodeUrl = "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=IRON-ROLL-001",
                        ReceivedDate = DateTime.UtcNow.AddDays(-30),
                        CreatedAt = DateTime.UtcNow.AddDays(-30),
                        UpdatedAt = DateTime.UtcNow.AddDays(-30)
                    };
                    mfgDb.InventoryRolls.Add(ironRoll);
                    await mfgDb.SaveChangesAsync();
                }
            }

            // Ensure historical defect report exists
            var ironDefect = await db.DefectReports.FirstOrDefaultAsync(d => d.BatchId == "BATCH-IRON-001" || (d.AffectedInventoryJson != null && d.AffectedInventoryJson.Contains("IRON-ROLL-001")));
            if (ironDefect == null)
            {
                ironDefect = new ManufacturingCoordinator.Models.Quality.DefectReport
                {
                    Id = Guid.NewGuid(),
                    BatchId = "BATCH-IRON-001",
                    ProductType = ProductType.Can,
                    Severity = DefectSeverity.MEDIUM,
                    Description = "Surface oxidation and micro-fractures detected on edge coil during ultrasonic scan",
                    AffectedInventoryJson = "[\"IRON-ROLL-001\"]",
                    Status = DefectStatus.InReview,
                    CreatedAt = DateTime.UtcNow.AddDays(-15)
                };
                db.DefectReports.Add(ironDefect);
                await db.SaveChangesAsync();
            }
        }

        private static async Task EnsureProcurementTablesAsync(ApplicationDbContext db)
        {
            if (!db.Database.IsRelational()) return;

            try
            {
                var sql = @"
                    CREATE TABLE IF NOT EXISTS ""ProcurementRequests"" (
                        ""Id"" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                        ""RawMaterialId"" integer NOT NULL,
                        ""RequiredSpecification"" character varying(200) NOT NULL,
                        ""ProductionRequirement"" numeric(18,3) NOT NULL,
                        ""CurrentStock"" numeric(18,3) NOT NULL,
                        ""SafetyStock"" numeric(18,3) NOT NULL,
                        ""ExistingOpenPoQuantity"" numeric(18,3) NOT NULL,
                        ""CalculatedNetQuantity"" numeric(18,3) NOT NULL,
                        ""MaximumBudget"" numeric(18,2) NOT NULL,
                        ""RequiredByDate"" timestamp with time zone NOT NULL,
                        ""QualityRequirement"" character varying(500) NOT NULL DEFAULT '',
                        ""PreferredRegion"" character varying(100),
                        ""Status"" text NOT NULL,
                        ""WorkflowId"" character varying(100),
                        ""MaterialName"" character varying(200),
                        ""RecommendedSupplierId"" integer,
                        ""GeneratedPurchaseOrderId"" integer,
                        ""FailureReason"" character varying(1000),
                        ""CreatedById"" uuid,
                        ""CreatedAt"" timestamp with time zone NOT NULL DEFAULT (timezone('utc', now())),
                        ""UpdatedAt"" timestamp with time zone NOT NULL DEFAULT (timezone('utc', now())),
                        CONSTRAINT ""FK_ProcurementRequests_RawMaterials_RawMaterialId"" FOREIGN KEY (""RawMaterialId"") REFERENCES ""RawMaterials"" (""Id"") ON DELETE RESTRICT,
                        CONSTRAINT ""FK_ProcurementRequests_Suppliers_RecommendedSupplierId"" FOREIGN KEY (""RecommendedSupplierId"") REFERENCES ""Suppliers"" (""Id"") ON DELETE SET NULL,
                        CONSTRAINT ""FK_ProcurementRequests_PurchaseOrders_GeneratedPurchaseOrderId"" FOREIGN KEY (""GeneratedPurchaseOrderId"") REFERENCES ""PurchaseOrders"" (""Id"") ON DELETE SET NULL,
                        CONSTRAINT ""FK_ProcurementRequests_Users_CreatedById"" FOREIGN KEY (""CreatedById"") REFERENCES ""Users"" (""Id"") ON DELETE SET NULL
                    );

                    CREATE TABLE IF NOT EXISTS ""SupplierCandidates"" (
                        ""Id"" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                        ""ProcurementRequestId"" integer NOT NULL,
                        ""SupplierId"" integer,
                        ""SupplierName"" character varying(200) NOT NULL,
                        ""MaterialName"" character varying(200) NOT NULL,
                        ""UnitPrice"" numeric(18,2) NOT NULL,
                        ""Currency"" character varying(10) NOT NULL DEFAULT 'USD',
                        ""MinimumOrderQuantity"" numeric(18,3) NOT NULL,
                        ""PackSize"" numeric(18,3) NOT NULL DEFAULT 1,
                        ""LeadTimeDays"" integer NOT NULL,
                        ""QualityEvidence"" character varying(500) NOT NULL DEFAULT '',
                        ""Availability"" character varying(100) NOT NULL DEFAULT 'In Stock',
                        ""SupplierStatus"" character varying(50) NOT NULL DEFAULT 'UNVERIFIED',
                        ""ConfidenceScore"" numeric(5,2) NOT NULL,
                        ""SourceUrl"" character varying(500),
                        ""IsValidated"" boolean NOT NULL,
                        ""ValidationRemarks"" character varying(1000),
                        ""RecommendedOrderQuantity"" numeric(18,3) NOT NULL,
                        ""TotalCost"" numeric(18,2) NOT NULL,
                        ""CreatedAt"" timestamp with time zone NOT NULL DEFAULT (timezone('utc', now())),
                        CONSTRAINT ""FK_SupplierCandidates_ProcurementRequests_ProcurementRequestId"" FOREIGN KEY (""ProcurementRequestId"") REFERENCES ""ProcurementRequests"" (""Id"") ON DELETE CASCADE,
                        CONSTRAINT ""FK_SupplierCandidates_Suppliers_SupplierId"" FOREIGN KEY (""SupplierId"") REFERENCES ""Suppliers"" (""Id"") ON DELETE SET NULL
                    );

                    ALTER TABLE ""ProcurementRequests"" ADD COLUMN IF NOT EXISTS ""WorkflowId"" character varying(100);
                    ALTER TABLE ""ProcurementRequests"" ADD COLUMN IF NOT EXISTS ""MaterialName"" character varying(200);
                    ALTER TABLE ""ProcurementRequests"" ADD COLUMN IF NOT EXISTS ""Priority"" character varying(50) DEFAULT 'Normal';
                    ALTER TABLE ""SupplierCandidates"" ADD COLUMN IF NOT EXISTS ""Availability"" character varying(100) DEFAULT 'In Stock';

                    -- Ensure StockAlerts procurement columns exist
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""MaterialId"" integer;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""MaterialName"" character varying(200);
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""CurrentStock"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""RequiredQuantity"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""SafetyStock"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""OpenPurchaseQuantity"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""NetDeficit"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""Severity"" character varying(50) DEFAULT 'Medium';
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""IsRead"" boolean NOT NULL DEFAULT false;

                    -- Ensure PurchaseOrders tracking, verification and delivery columns exist
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""ProcurementRequestId"" integer;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""TrackingStatus"" character varying(50) DEFAULT 'Draft';
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""ExpectedDeliveryDate"" timestamp with time zone;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""ActualDeliveryDate"" timestamp with time zone;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""IsAcknowledgedByScm"" boolean NOT NULL DEFAULT false;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""IsQualityVerified"" boolean NOT NULL DEFAULT false;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""IsFinancialVerified"" boolean NOT NULL DEFAULT false;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""CompletedAt"" timestamp with time zone;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""TrackingNumber"" character varying(200);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""DeliveryRemarks"" character varying(500);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""StripePaymentIntentId"" character varying(200);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""StripePaymentStatus"" character varying(50);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""PaymentFailureReason"" character varying(500);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""BankSlipUrl"" character varying(500);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""BankReferenceNumber"" character varying(100);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""BankSlipStatus"" character varying(50);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""BankSlipUploadedAt"" timestamp with time zone;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""SendGridMessageId"" character varying(200);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""EmailStatus"" character varying(50);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""EmailSentAt"" timestamp with time zone;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""EmailFailureReason"" character varying(500);
                    ALTER TABLE ""AgentWorkflows"" ADD COLUMN IF NOT EXISTS ""ValidationResults"" text;

                    CREATE TABLE IF NOT EXISTS ""ProcurementOutcomes"" (
                        ""Id"" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                        ""Material"" character varying(200) NOT NULL,
                        ""RequestedQuantity"" numeric(18,3) NOT NULL,
                        ""RecommendedQuantity"" numeric(18,3) NOT NULL,
                        ""FinalOrderedQuantity"" numeric(18,3) NOT NULL,
                        ""RecommendedSupplier"" character varying(200) NOT NULL,
                        ""SelectedSupplier"" character varying(200) NOT NULL,
                        ""EstimatedPrice"" numeric(18,2) NOT NULL,
                        ""FinalPrice"" numeric(18,2) NOT NULL,
                        ""EstimatedLeadTime"" integer NOT NULL,
                        ""ActualLeadTime"" integer NOT NULL,
                        ""QualityEvidence"" character varying(1000) NOT NULL DEFAULT '',
                        ""SupplierVerification"" character varying(100) NOT NULL DEFAULT 'VERIFIED',
                        ""ManagerDecision"" character varying(100) NOT NULL,
                        ""ManagerRevision"" character varying(1000),
                        ""ProcurementSuccess"" boolean NOT NULL DEFAULT true,
                        ""PaymentSuccess"" boolean NOT NULL DEFAULT true,
                        ""DeliverySuccess"" boolean NOT NULL DEFAULT false,
                        ""QualityOutcome"" character varying(500),
                        ""CreatedAt"" timestamp with time zone NOT NULL DEFAULT (timezone('utc', now())),
                        ""CompletedAt"" timestamp with time zone,
                        ""PurchaseOrderId"" integer,
                        ""ProcurementRequestId"" integer
                    );
                ";
                await db.Database.ExecuteSqlRawAsync(sql);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Procurement tables creation/check notice: {ex.Message}");
            }
        }
    }
}
