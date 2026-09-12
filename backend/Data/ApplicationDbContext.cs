using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.PurchaseOrders;
using backend.Models;

namespace ManufacturingCoordinator.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        // Authentication
        public DbSet<User> Users { get; set; } = null!;
        public DbSet<OtpVerification> OtpVerifications { get; set; } = null!;
        public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;

        // Student 2 — Purchase Order Management
        public DbSet<Supplier> Suppliers { get; set; } = null!;
        public DbSet<PurchaseOrder> PurchaseOrders { get; set; } = null!;
        public DbSet<OrderLine> OrderLines { get; set; } = null!;
        public DbSet<RawMaterial> RawMaterials { get; set; } = null!;

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

                // Speeds up lookups during verify: WHERE UserId = ? AND Purpose = ? AND IsUsed = false
                entity.HasIndex(o => new { o.UserId, o.Purpose, o.IsUsed });
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

            // ── Supplier ──────────────────────────────────────────────────────────
            modelBuilder.Entity<Supplier>(entity =>
            {
                entity.HasKey(s => s.Id);

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

                entity.Property(s => s.IsActive)
                    .HasDefaultValue(true);

                entity.Property(s => s.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(s => s.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");
            });

            // ── PurchaseOrder ─────────────────────────────────────────────────────
            modelBuilder.Entity<PurchaseOrder>(entity =>
            {
                entity.HasKey(po => po.Id);

                entity.Property(po => po.PoNumber)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.HasIndex(po => po.PoNumber)
                    .IsUnique();

                // Store enum as readable string
                entity.Property(po => po.Status)
                    .HasConversion<string>()
                    .IsRequired();

                entity.HasIndex(po => po.Status);
                entity.HasIndex(po => po.SupplierId);

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

                entity.Property(po => po.SendGridMessageId)
                    .HasMaxLength(200);

                entity.Property(po => po.CreatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.Property(po => po.UpdatedAt)
                    .HasDefaultValueSql("timezone('utc', now())");

                entity.HasOne(po => po.Supplier)
                    .WithMany(s => s.PurchaseOrders)
                    .HasForeignKey(po => po.SupplierId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(po => po.ApprovedBy)
                    .WithMany()
                    .HasForeignKey(po => po.ApprovedById)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            // ── OrderLine ─────────────────────────────────────────────────────────
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
                // We reference the table by name since they are in different DbContexts
                entity.HasOne(ol => ol.RawMaterial)
                    .WithMany()
                    .HasForeignKey(ol => ol.RawMaterialId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            // ── RawMaterial (Existing table from Student 1) ───────────────────────
            modelBuilder.Entity<RawMaterial>(entity =>
            {
                entity.ToTable("RawMaterials");
                entity.HasKey(rm => rm.Id);
                entity.Property(rm => rm.SkuCode).IsRequired().HasMaxLength(50);
                entity.HasIndex(rm => rm.SkuCode).IsUnique();
            });
        }
    }
}