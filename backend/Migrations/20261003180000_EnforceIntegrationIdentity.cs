using ManufacturingCoordinator.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace ManufacturingCoordinator.Api.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20261003180000_EnforceIntegrationIdentity")]
public class EnforceIntegrationIdentity : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.Sql("""
        -- Stop on historical duplicates; preserve them for manual reconciliation.
        CREATE UNIQUE INDEX IF NOT EXISTS "IX_InventoryRolls_IdentifierNormalized"
            ON "InventoryRolls" (upper("RollIdentifier"));
        CREATE UNIQUE INDEX IF NOT EXISTS "UX_PurchaseOrders_ProcurementRequestId"
            ON "PurchaseOrders" ("ProcurementRequestId") WHERE "ProcurementRequestId" IS NOT NULL;
        """);
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_InventoryRolls_IdentifierNormalized\";");
        migrationBuilder.Sql("DROP INDEX IF EXISTS \"UX_PurchaseOrders_ProcurementRequestId\";");
    }
}
