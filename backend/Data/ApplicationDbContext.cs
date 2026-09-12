using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.Production;
using ManufacturingCoordinator.Models.Administration;

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

        // Production (Student 4)
        public DbSet<Machine> Machines { get; set; } = null!;
        public DbSet<MaintenanceLog> MaintenanceLogs { get; set; } = null!;
        public DbSet<Shift> Shifts { get; set; } = null!;

        // Administration (Student 4)
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
        }
    }
}