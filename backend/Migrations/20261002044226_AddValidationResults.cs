using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class AddValidationResults : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "CurrentStock",
                table: "StockAlerts",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<bool>(
                name: "IsRead",
                table: "StockAlerts",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "MaterialId",
                table: "StockAlerts",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MaterialName",
                table: "StockAlerts",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "NetDeficit",
                table: "StockAlerts",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "OpenPurchaseQuantity",
                table: "StockAlerts",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "RequiredQuantity",
                table: "StockAlerts",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "SafetyStock",
                table: "StockAlerts",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "Severity",
                table: "StockAlerts",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CurrentStock",
                table: "StockAlerts");

            migrationBuilder.DropColumn(
                name: "IsRead",
                table: "StockAlerts");

            migrationBuilder.DropColumn(
                name: "MaterialId",
                table: "StockAlerts");

            migrationBuilder.DropColumn(
                name: "MaterialName",
                table: "StockAlerts");

            migrationBuilder.DropColumn(
                name: "NetDeficit",
                table: "StockAlerts");

            migrationBuilder.DropColumn(
                name: "OpenPurchaseQuantity",
                table: "StockAlerts");

            migrationBuilder.DropColumn(
                name: "RequiredQuantity",
                table: "StockAlerts");

            migrationBuilder.DropColumn(
                name: "SafetyStock",
                table: "StockAlerts");

            migrationBuilder.DropColumn(
                name: "Severity",
                table: "StockAlerts");
        }
    }
}
