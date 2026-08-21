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

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<InventoryItem>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Sku).IsRequired();
                entity.Property(e => e.Name).IsRequired();
            });

            modelBuilder.Entity<StockAlert>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Sku).IsRequired();
                entity.Property(e => e.PackagingType).IsRequired();
            });
        }
    }
}
