using backend.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace ManufacturingCoordinator.Data;

// Model generation never boots the API, seeds data, or connects to the deployment DB.
public sealed class ApplicationContextFactory : IDesignTimeDbContextFactory<ApplicationDbContext>
{
    public ApplicationDbContext CreateDbContext(string[] args) => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseNpgsql(Environment.GetEnvironmentVariable("AMIC_MIGRATION_CONNECTION") ??
            "Host=localhost;Database=amic_design_only;Username=design;Password=design").Options);
}

public sealed class ManufacturingContextFactory : IDesignTimeDbContextFactory<ManufacturingContext>
{
    public ManufacturingContext CreateDbContext(string[] args) => new(new DbContextOptionsBuilder<ManufacturingContext>()
        .UseNpgsql(Environment.GetEnvironmentVariable("AMIC_MIGRATION_CONNECTION") ??
            "Host=localhost;Database=amic_design_only;Username=design;Password=design").Options);
}
