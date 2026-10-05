using ManufacturingCoordinator.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
namespace ManufacturingCoordinator.Api.Migrations;
[DbContext(typeof(ApplicationDbContext))]
[Migration("20261005010000_AddShiftMaterialContext")]
public class AddShiftMaterialContext : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.Sql("""
        ALTER TABLE "Shifts" ADD COLUMN IF NOT EXISTS "MaterialSku" text;
        ALTER TABLE "Shifts" ADD COLUMN IF NOT EXISTS "MachineId" uuid;
        ALTER TABLE "Shifts" ADD COLUMN IF NOT EXISTS "MaterialPerUnit" numeric;
        """);
    // Preserve associations if an application rollback is needed.
    protected override void Down(MigrationBuilder migrationBuilder) { }
}
