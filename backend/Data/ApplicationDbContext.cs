using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Models.Authentication;

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

        // TODO: other students' DbSets (Inventory, PurchaseOrders, Quality, Production) go here too

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
        }
    }
}