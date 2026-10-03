using Microsoft.EntityFrameworkCore;
using backend.Models;

namespace backend.Data
{
    public class ManufacturingContext : DbContext
    {
        public ManufacturingContext(DbContextOptions<ManufacturingContext> options)
            : base(options)
        {
        }

        public DbSet<InventoryItem> InventoryItems { get; set; } = null!;
        public DbSet<StockAlert> StockAlerts { get; set; } = null!;
        
        // New Entities for Student A
        public DbSet<RawMaterial> RawMaterials { get; set; } = null!;
        public DbSet<InventoryRoll> InventoryRolls { get; set; } = null!;
        public DbSet<StockLevel> StockLevels { get; set; } = null!;
        public DbSet<PackagingType> PackagingTypes { get; set; } = null!;

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<InventoryItem>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Sku).IsRequired();
                entity.Property(e => e.Name).IsRequired();
                entity.HasIndex(e => e.Sku).IsUnique();
            });

            modelBuilder.Entity<PackagingType>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
                entity.Property(e => e.ShortCode).IsRequired().HasMaxLength(12);
                entity.HasIndex(e => e.Name).IsUnique();
                entity.HasIndex(e => e.ShortCode).IsUnique();
            });

            modelBuilder.Entity<StockAlert>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Sku).IsRequired();
                entity.Property(e => e.PackagingType).IsRequired();
            });

            // RawMaterial config
            modelBuilder.Entity<RawMaterial>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.SkuCode).IsRequired().HasMaxLength(255);
                entity.HasIndex(e => e.SkuCode).IsUnique();
                entity.Property(e => e.Name).IsRequired();
                entity.Property(e => e.MaterialCode).IsRequired().HasMaxLength(20);
                entity.HasIndex(e => new { e.PackagingTypeId, e.MaterialCode });
                entity.HasOne(e => e.PackagingType)
                      .WithMany(p => p.RawMaterials)
                      .HasForeignKey(e => e.PackagingTypeId)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // InventoryRoll config
            modelBuilder.Entity<InventoryRoll>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.RollIdentifier).IsRequired();
                entity.HasIndex(e => e.RollIdentifier).IsUnique();
                
                // One-to-Many Relationship
                entity.HasOne(e => e.RawMaterial)
                      .WithMany(r => r.InventoryRolls)
                      .HasForeignKey(e => e.RawMaterialId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // StockLevel config
            modelBuilder.Entity<StockLevel>(entity =>
            {
                entity.HasKey(e => e.Id);
                
                // One-to-Many Relationship
                entity.HasOne(e => e.RawMaterial)
                      .WithMany(r => r.StockLevels)
                      .HasForeignKey(e => e.RawMaterialId)
                      .OnDelete(DeleteBehavior.Cascade);
            });
        }
    }
}
