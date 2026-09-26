using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Models.Inventory;
using ManufacturingCoordinator.Models.Quality;
using ManufacturingCoordinator.Models.Production;
using ManufacturingCoordinator.Models.Administration;
using backend.Models;

namespace ManufacturingCoordinator.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        // Authentication (Student 1)
        public DbSet<User> Users { get; set; } = null!;
        public DbSet<OtpVerification> OtpVerifications { get; set; } = null!;
        public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;

        // Student 2 — Purchase Order Management
        public DbSet<Supplier> Suppliers { get; set; } = null!;
        public DbSet<PurchaseOrder> PurchaseOrders { get; set; } = null!;
        public DbSet<OrderLine> OrderLines { get; set; } = null!;
        public DbSet<RawMaterial> RawMaterials { get; set; } = null!;
        public DbSet<PurchaseOrderApproval> PurchaseOrderApprovals { get; set; } = null!;
        public DbSet<PaymentTransaction> PaymentTransactions { get; set; } = null!;
        public DbSet<SupplierPerformance> SupplierPerformances { get; set; } = null!;
        public DbSet<ProcurementRequest> ProcurementRequests { get; set; } = null!;
        public DbSet<SupplierCandidate> SupplierCandidates { get; set; } = null!;
        public DbSet<ProcurementOutcome> ProcurementOutcomes { get; set; } = null!;

        // Student 3 — QA / Defect Reporting & Inventory
        public DbSet<DefectReport> DefectReports { get; set; } = null!;
        public DbSet<Quarantine> Quarantines { get; set; } = null!;
        public DbSet<Batch> Batches { get; set; } = null!;
        public DbSet<ManufacturingCoordinator.Models.Inventory.InventoryRoll> InventoryRolls { get; set; } = null!;

        // Student 4 — Production
        public DbSet<Machine> Machines { get; set; } = null!;
        public DbSet<MaintenanceLog> MaintenanceLogs { get; set; } = null!;
        public DbSet<Shift> Shifts { get; set; } = null!;

        // Student 4 — Administration
        public DbSet<AuditLog> AuditLogs { get; set; } = null!;
        public DbSet<AgentWorkflow> AgentWorkflows { get; set; } = null!;

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // ---- User ----
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasKey(u => u.Id);

                entity.Property(u => u.FullName)
                    .IsRequired()
                    .HasMaxLength(150);

                entity.Property(u => u.Email)
                    .IsRequired()
                    .HasMaxLength(256);

                entity.HasIndex(u => u.Email)
                    .IsUnique();

                entity.Property(u => u.PasswordHash)
                    .IsRequired();

                entity.Property(u => u.Role)
                    .HasConversion<string>() // store enum as readable string in Postgres
                    .IsRequired();

                entity.Property(u => u.IsEmailVerified)
                    .HasDefaultValue(false);

                entity.Property(u => u.IsActive)
                    .HasDefaultValue(true);

                entity.Property(u => u.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(u => u.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");
            });

            // ---- OtpVerification ----
            modelBuilder.Entity<OtpVerification>(entity =>
            {
                entity.HasKey(o => o.Id);

                entity.Property(o => o.Code)
                    .IsRequired()
                    .HasMaxLength(6);

                entity.Property(o => o.Purpose)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(o => o.ExpiresAt)
                    .IsRequired();

                entity.Property(o => o.IsUsed)
                    .HasDefaultValue(false);

                entity.Property(o => o.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(o => o.User)
                    .WithMany(u => u.OtpVerifications)
                    .HasForeignKey(o => o.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(o => new { o.UserId, o.Code, o.Purpose });
            });

            // ---- RefreshToken ----
            modelBuilder.Entity<RefreshToken>(entity =>
            {
                entity.HasKey(r => r.Id);

                entity.Property(r => r.TokenHash)
                    .IsRequired();

                entity.Property(r => r.ExpiresAt)
                    .IsRequired();

                entity.Property(r => r.IsRevoked)
                    .HasDefaultValue(false);

                entity.Property(r => r.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(r => r.User)
                    .WithMany(u => u.RefreshTokens)
                    .HasForeignKey(r => r.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(r => r.TokenHash);
            });

            // ── Supplier (Student 2) ──────────────────────────────────────────────
            modelBuilder.Entity<Supplier>(entity =>
            {
                entity.HasKey(s => s.Id);

                entity.Property(s => s.SupplierCode)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.HasIndex(s => s.SupplierCode)
                    .IsUnique();

                entity.Property(s => s.Name)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(s => s.ContactEmail)
                    .IsRequired()
                    .HasMaxLength(256);

                entity.HasIndex(s => s.ContactEmail)
                    .IsUnique();

                entity.Property(s => s.ContactPhone)
                    .HasMaxLength(30);

                entity.Property(s => s.Address)
                    .HasMaxLength(500);

                entity.Property(s => s.PaymentTerms)
                    .HasMaxLength(50)
                    .HasDefaultValue("Net 30");

                entity.Property(s => s.LeadTimeDays)
                    .HasDefaultValue(7);

                entity.Property(s => s.IsActive)
                    .HasDefaultValue(true);

                entity.Property(s => s.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(s => s.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");
            });

            // ---- DefectReport (Student 3) ----
            modelBuilder.Entity<DefectReport>(entity =>
            {
                entity.HasKey(d => d.Id);

                entity.Property(d => d.BatchId)
                    .IsRequired()
                    .HasMaxLength(80);

                entity.Property(d => d.ProductType)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(d => d.Severity)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(d => d.Description)
                    .IsRequired()
                    .HasMaxLength(1000);

                entity.Property(d => d.AffectedInventoryJson)
                    .IsRequired()
                    .HasDefaultValue("[]");

                entity.Property(d => d.Status)
                    .HasConversion<string>()
                    .HasDefaultValue(DefectStatus.Open);

                entity.Property(d => d.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(d => d.ReportedByUser)
                    .WithMany()
                    .HasForeignKey(d => d.ReportedByUserId)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            modelBuilder.Entity<Batch>(entity =>
            {
                entity.HasKey(b => b.Id);
                entity.Property(b => b.Id).HasMaxLength(80);
                entity.Property(b => b.ProductType).HasConversion<string>().IsRequired();
            });

            modelBuilder.Entity<ManufacturingCoordinator.Models.Inventory.InventoryRoll>(entity =>
            {
                entity.HasKey(i => i.Id);
                entity.Property(i => i.Id).HasMaxLength(120);
                entity.Property(i => i.BatchId).IsRequired().HasMaxLength(80);
                entity.Property(i => i.Status).HasConversion<string>().IsRequired();
                entity.HasOne(i => i.Batch)
                    .WithMany(b => b.InventoryRolls)
                    .HasForeignKey(i => i.BatchId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasIndex(i => new { i.BatchId, i.Status });
            });

            modelBuilder.Entity<Quarantine>(entity =>
            {
                entity.HasKey(q => q.Id);

                entity.Property(q => q.InventoryRollId)
                    .IsRequired()
                    .HasMaxLength(120);

                entity.Property(q => q.Reason)
                    .IsRequired()
                    .HasMaxLength(1000);

                entity.Property(q => q.Status)
                    .HasConversion<string>()
                    .HasDefaultValue(QuarantineStatus.Active);

                entity.Property(q => q.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(q => q.DefectReport)
                    .WithMany()
                    .HasForeignKey(q => q.DefectReportId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(q => new { q.InventoryRollId, q.Status });
            });

            // ---- Machine (Student 4) ----
            modelBuilder.Entity<Machine>(entity =>
            {
                entity.HasKey(m => m.Id);

                entity.Property(m => m.Name)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(m => m.Status)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(m => m.UptimeHours)
                    .IsRequired();

                entity.Property(m => m.MaintenanceIntervalHours)
                    .IsRequired();

                entity.Property(m => m.Location)
                    .HasMaxLength(300);

                entity.Property(m => m.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(m => m.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasIndex(m => m.Name);
            });

            // ---- MaintenanceLog (Student 4) ----
            modelBuilder.Entity<MaintenanceLog>(entity =>
            {
                entity.HasKey(ml => ml.Id);

                entity.Property(ml => ml.Description)
                    .IsRequired()
                    .HasMaxLength(1000);

                entity.Property(ml => ml.PerformedBy)
                    .IsRequired()
                    .HasMaxLength(150);

                entity.Property(ml => ml.Type)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(ml => ml.PerformedAt)
                    .IsRequired();

                entity.Property(ml => ml.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(ml => ml.Machine)
                    .WithMany(m => m.MaintenanceLogs)
                    .HasForeignKey(ml => ml.MachineId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(ml => ml.MachineId);
            });

            // ---- Shift (Student 4) ----
            modelBuilder.Entity<Shift>(entity =>
            {
                entity.HasKey(s => s.Id);

                entity.Property(s => s.Name)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(s => s.ProductionTarget)
                    .IsRequired();

                entity.Property(s => s.AvailableMaterial)
                    .IsRequired();

                entity.Property(s => s.AdjustedOutput)
                    .IsRequired();

                entity.Property(s => s.ActualOutput)
                    .IsRequired();

                entity.Property(s => s.Status)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(s => s.StartTime)
                    .IsRequired();

                entity.Property(s => s.EndTime)
                    .IsRequired();

                entity.Property(s => s.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(s => s.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");
            });

            // ── PurchaseOrder (Student 2) ─────────────────────────────────────────
            modelBuilder.Entity<PurchaseOrder>(entity =>
            {
                entity.HasKey(po => po.Id);

                entity.Property(po => po.PoNumber)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.HasIndex(po => po.PoNumber)
                    .IsUnique();

                entity.Property(po => po.Status)
                    .HasConversion<string>()
                    .IsRequired();

                entity.HasIndex(po => po.Status);
                entity.HasIndex(po => po.SupplierId);

                entity.Property(po => po.Currency)
                    .HasMaxLength(10)
                    .HasDefaultValue("USD");

                entity.Property(po => po.TotalCost)
                    .HasColumnType("decimal(18,2)");

                entity.Property(po => po.BudgetLimit)
                    .HasColumnType("decimal(18,2)");

                entity.Property(po => po.ApprovalThreshold)
                    .HasColumnType("decimal(18,2)")
                    .HasDefaultValue(5000m);

                entity.Property(po => po.Notes)
                    .HasMaxLength(1000);

                entity.Property(po => po.RejectionReason)
                    .HasMaxLength(1000);

                entity.Property(po => po.StripePaymentIntentId)
                    .HasMaxLength(200);

                entity.Property(po => po.StripePaymentStatus)
                    .HasMaxLength(50);

                entity.Property(po => po.PaymentFailureReason)
                    .HasMaxLength(500);

                entity.Property(po => po.SendGridMessageId)
                    .HasMaxLength(200);

                entity.Property(po => po.EmailStatus)
                    .HasMaxLength(50);

                entity.Property(po => po.EmailFailureReason)
                    .HasMaxLength(500);

                entity.Property(po => po.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(po => po.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(po => po.Supplier)
                    .WithMany(s => s.PurchaseOrders)
                    .HasForeignKey(po => po.SupplierId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(po => po.CreatedBy)
                    .WithMany()
                    .HasForeignKey(po => po.CreatedById)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(po => po.ApprovedBy)
                    .WithMany()
                    .HasForeignKey(po => po.ApprovedById)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            // ── PurchaseOrderApproval (Audit - Student 2) ─────────────────────────
            modelBuilder.Entity<PurchaseOrderApproval>(entity =>
            {
                entity.HasKey(a => a.Id);

                entity.Property(a => a.Action)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(a => a.UserName)
                    .HasMaxLength(150);

                entity.Property(a => a.Notes)
                    .HasMaxLength(1000);

                entity.Property(a => a.Timestamp)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(a => a.PurchaseOrder)
                    .WithMany(po => po.Approvals)
                    .HasForeignKey(a => a.PurchaseOrderId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(a => a.User)
                    .WithMany()
                    .HasForeignKey(a => a.UserId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasIndex(a => a.PurchaseOrderId);
            });

            // ── PaymentTransaction (Student 2) ────────────────────────────────────
            modelBuilder.Entity<PaymentTransaction>(entity =>
            {
                entity.HasKey(pt => pt.Id);

                entity.Property(pt => pt.Amount)
                    .HasColumnType("decimal(18,2)")
                    .IsRequired();

                entity.Property(pt => pt.Currency)
                    .HasMaxLength(10)
                    .HasDefaultValue("usd");

                entity.Property(pt => pt.PaymentStatus)
                    .HasMaxLength(50)
                    .IsRequired();

                entity.Property(pt => pt.TransactionId)
                    .HasMaxLength(200);

                entity.Property(pt => pt.FailureReason)
                    .HasMaxLength(500);

                entity.Property(pt => pt.Timestamp)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(pt => pt.PurchaseOrder)
                    .WithMany(po => po.Transactions)
                    .HasForeignKey(pt => pt.PurchaseOrderId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(pt => pt.PurchaseOrderId);
            });

            // ── SupplierPerformance (Student 2) ───────────────────────────────────
            modelBuilder.Entity<SupplierPerformance>(entity =>
            {
                entity.HasKey(sp => sp.Id);

                entity.Property(sp => sp.TotalSpending)
                    .HasColumnType("decimal(18,2)");

                entity.Property(sp => sp.AverageOrderValue)
                    .HasColumnType("decimal(18,2)");

                entity.Property(sp => sp.AverageLeadTime)
                    .HasColumnType("decimal(18,2)");

                entity.Property(sp => sp.DeliveryPerformanceRate)
                    .HasColumnType("decimal(5,2)");

                entity.Property(sp => sp.RejectionRate)
                    .HasColumnType("decimal(5,2)");

                entity.Property(sp => sp.CalculatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(sp => sp.Supplier)
                    .WithMany()
                    .HasForeignKey(sp => sp.SupplierId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(sp => sp.SupplierId);
            });

            // ── OrderLine (Student 2) ─────────────────────────────────────────────
            modelBuilder.Entity<OrderLine>(entity =>
            {
                entity.HasKey(ol => ol.Id);

                entity.Property(ol => ol.Description)
                    .HasMaxLength(500);

                entity.Property(ol => ol.Quantity)
                    .HasColumnType("decimal(18,3)")
                    .IsRequired();

                entity.Property(ol => ol.UnitPrice)
                    .HasColumnType("decimal(18,2)")
                    .IsRequired();

                entity.Property(ol => ol.TotalPrice)
                    .HasColumnType("decimal(18,2)");

                entity.Property(ol => ol.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(ol => ol.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasIndex(ol => ol.PurchaseOrderId);
                entity.HasIndex(ol => ol.RawMaterialId);

                entity.HasOne(ol => ol.PurchaseOrder)
                    .WithMany(po => po.OrderLines)
                    .HasForeignKey(ol => ol.PurchaseOrderId)
                    .OnDelete(DeleteBehavior.Cascade);

                // FK to RawMaterial (Student 1 entity — in ManufacturingContext)
                entity.HasOne(ol => ol.RawMaterial)
                    .WithMany()
                    .HasForeignKey(ol => ol.RawMaterialId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            // ── RawMaterial (Student 1) ───────────────────────────────────────────
            modelBuilder.Entity<RawMaterial>(entity =>
            {
                entity.ToTable("RawMaterials");
                entity.HasKey(rm => rm.Id);
                entity.Property(rm => rm.SkuCode).IsRequired().HasMaxLength(50);
                entity.HasIndex(rm => rm.SkuCode).IsUnique();
            });

            // ---- AuditLog (Student 4) ----
            modelBuilder.Entity<AuditLog>(entity =>
            {
                entity.HasKey(a => a.Id);

                entity.Property(a => a.UserName)
                    .IsRequired()
                    .HasMaxLength(150);

                entity.Property(a => a.Action)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(a => a.Entity)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(a => a.EntityId)
                    .HasMaxLength(100);

                entity.Property(a => a.Timestamp)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(a => a.Success)
                    .HasDefaultValue(true);

                entity.Property(a => a.IpAddress)
                    .HasMaxLength(50);

                entity.HasIndex(a => a.UserId);
                entity.HasIndex(a => a.Action);
                entity.HasIndex(a => a.Entity);
                entity.HasIndex(a => a.Timestamp);
            });

            // ---- AgentWorkflow (Student 4) ----
            modelBuilder.Entity<AgentWorkflow>(entity =>
            {
                entity.HasKey(w => w.Id);

                entity.Property(w => w.WorkflowId)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.HasIndex(w => w.WorkflowId)
                    .IsUnique();

                entity.Property(w => w.Objective)
                    .IsRequired()
                    .HasMaxLength(500);

                entity.Property(w => w.CurrentAgent)
                    .HasMaxLength(200);

                entity.Property(w => w.Status)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(w => w.ApprovalStatus)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(w => w.StartedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(w => w.FinalOutcome)
                    .HasMaxLength(1000);
            });

            // ── ProcurementRequest (Student 2) ───────────────────────────────────
            modelBuilder.Entity<ProcurementRequest>(entity =>
            {
                entity.HasKey(pr => pr.Id);

                entity.Property(pr => pr.RequiredSpecification)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(pr => pr.ProductionRequirement)
                    .HasColumnType("decimal(18,3)");

                entity.Property(pr => pr.CurrentStock)
                    .HasColumnType("decimal(18,3)");

                entity.Property(pr => pr.SafetyStock)
                    .HasColumnType("decimal(18,3)");

                entity.Property(pr => pr.ExistingOpenPoQuantity)
                    .HasColumnType("decimal(18,3)");

                entity.Property(pr => pr.CalculatedNetQuantity)
                    .HasColumnType("decimal(18,3)");

                entity.Property(pr => pr.MaximumBudget)
                    .HasColumnType("decimal(18,2)");

                entity.Property(pr => pr.QualityRequirement)
                    .HasMaxLength(500);

                entity.Property(pr => pr.PreferredRegion)
                    .HasMaxLength(100);

                entity.Property(pr => pr.Status)
                    .HasConversion<string>()
                    .IsRequired();

                entity.Property(pr => pr.WorkflowId)
                    .HasMaxLength(100);

                entity.Property(pr => pr.MaterialName)
                    .HasMaxLength(200);

                entity.Property(pr => pr.FailureReason)
                    .HasMaxLength(1000);

                entity.Property(pr => pr.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(pr => pr.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(pr => pr.RawMaterial)
                    .WithMany()
                    .HasForeignKey(pr => pr.RawMaterialId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(pr => pr.RecommendedSupplier)
                    .WithMany()
                    .HasForeignKey(pr => pr.RecommendedSupplierId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(pr => pr.GeneratedPurchaseOrder)
                    .WithMany()
                    .HasForeignKey(pr => pr.GeneratedPurchaseOrderId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(pr => pr.CreatedBy)
                    .WithMany()
                    .HasForeignKey(pr => pr.CreatedById)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            // ── SupplierCandidate (Student 2) ────────────────────────────────────
            modelBuilder.Entity<SupplierCandidate>(entity =>
            {
                entity.HasKey(sc => sc.Id);

                entity.Property(sc => sc.SupplierName)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(sc => sc.MaterialName)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(sc => sc.UnitPrice)
                    .HasColumnType("decimal(18,2)");

                entity.Property(sc => sc.Currency)
                    .HasMaxLength(10)
                    .HasDefaultValue("USD");

                entity.Property(sc => sc.MinimumOrderQuantity)
                    .HasColumnType("decimal(18,3)");

                entity.Property(sc => sc.PackSize)
                    .HasColumnType("decimal(18,3)")
                    .HasDefaultValue(1m);

                entity.Property(sc => sc.QualityEvidence)
                    .HasMaxLength(500);

                entity.Property(sc => sc.Availability)
                    .HasMaxLength(100)
                    .HasDefaultValue("In Stock");

                entity.Property(sc => sc.SupplierStatus)
                    .IsRequired()
                    .HasMaxLength(50)
                    .HasDefaultValue("UNVERIFIED");

                entity.Property(sc => sc.ConfidenceScore)
                    .HasColumnType("decimal(5,2)");

                entity.Property(sc => sc.SourceUrl)
                    .HasMaxLength(500);

                entity.Property(sc => sc.ValidationRemarks)
                    .HasMaxLength(1000);

                entity.Property(sc => sc.RecommendedOrderQuantity)
                    .HasColumnType("decimal(18,3)");

                entity.Property(sc => sc.TotalCost)
                    .HasColumnType("decimal(18,2)");

                entity.Property(sc => sc.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(sc => sc.ProcurementRequest)
                    .WithMany(pr => pr.Candidates)
                    .HasForeignKey(sc => sc.ProcurementRequestId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(sc => sc.Supplier)
                    .WithMany()
                    .HasForeignKey(sc => sc.SupplierId)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            // ── ProcurementOutcome (Student 2 - Future Learning Dataset) ─────────
            modelBuilder.Entity<ProcurementOutcome>(entity =>
            {
                entity.HasKey(po => po.Id);
                entity.Property(po => po.Material).IsRequired().HasMaxLength(200);
                entity.Property(po => po.RecommendedSupplier).IsRequired().HasMaxLength(200);
                entity.Property(po => po.SelectedSupplier).IsRequired().HasMaxLength(200);
                entity.Property(po => po.RequestedQuantity).HasColumnType("decimal(18,3)");
                entity.Property(po => po.RecommendedQuantity).HasColumnType("decimal(18,3)");
                entity.Property(po => po.FinalOrderedQuantity).HasColumnType("decimal(18,3)");
                entity.Property(po => po.EstimatedPrice).HasColumnType("decimal(18,2)");
                entity.Property(po => po.FinalPrice).HasColumnType("decimal(18,2)");
                entity.Property(po => po.QualityEvidence).HasMaxLength(1000);
                entity.Property(po => po.SupplierVerification).HasMaxLength(100);
                entity.Property(po => po.ManagerDecision).IsRequired().HasMaxLength(100);
                entity.Property(po => po.ManagerRevision).HasMaxLength(1000);
                entity.Property(po => po.QualityOutcome).HasMaxLength(500);
                entity.Property(po => po.CreatedAt).HasDefaultValueSql("timezone('utc', now())");
            });
        }
    }
}