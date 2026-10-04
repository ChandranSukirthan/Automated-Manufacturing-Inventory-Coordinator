using ManufacturingCoordinator.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace ManufacturingCoordinator.Api.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20261004010000_CompleteUserIdentitySchema")]
public class CompleteUserIdentitySchema : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.Sql("""
        ALTER TABLE "Users" ADD COLUMN IF NOT EXISTS "EmployeeId" character varying(16);
        CREATE UNIQUE INDEX IF NOT EXISTS "IX_Users_EmployeeId" ON "Users" ("EmployeeId") WHERE "EmployeeId" IS NOT NULL;
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "MaterialId" integer;
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "MaterialName" character varying(200);
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "CurrentStock" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "RequiredQuantity" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "SafetyStock" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "OpenPurchaseQuantity" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "NetDeficit" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "Severity" character varying(50) NOT NULL DEFAULT 'Unknown';
        ALTER TABLE "StockAlerts" ADD COLUMN IF NOT EXISTS "IsRead" boolean NOT NULL DEFAULT FALSE;
        """);
    protected override void Down(MigrationBuilder migrationBuilder) { }
}
