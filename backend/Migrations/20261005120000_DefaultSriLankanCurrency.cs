using ManufacturingCoordinator.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace ManufacturingCoordinator.Api.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20261005120000_DefaultSriLankanCurrency")]
public class DefaultSriLankanCurrency : Migration
{
    // Defaults affect new records only. Existing foreign-currency history is retained.
    protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.Sql("""
        ALTER TABLE "PurchaseOrders" ALTER COLUMN "Currency" SET DEFAULT 'LKR';
        ALTER TABLE "PurchaseOrders" ALTER COLUMN "ApprovalThreshold" SET DEFAULT 1500000;
        ALTER TABLE "PaymentTransactions" ALTER COLUMN "Currency" SET DEFAULT 'lkr';
        ALTER TABLE "SupplierCandidates" ALTER COLUMN "Currency" SET DEFAULT 'LKR';
        """);

    protected override void Down(MigrationBuilder migrationBuilder) => migrationBuilder.Sql("""
        ALTER TABLE "PurchaseOrders" ALTER COLUMN "Currency" SET DEFAULT 'USD';
        ALTER TABLE "PurchaseOrders" ALTER COLUMN "ApprovalThreshold" SET DEFAULT 5000;
        ALTER TABLE "PaymentTransactions" ALTER COLUMN "Currency" SET DEFAULT 'usd';
        ALTER TABLE "SupplierCandidates" ALTER COLUMN "Currency" SET DEFAULT 'USD';
        """);
}
