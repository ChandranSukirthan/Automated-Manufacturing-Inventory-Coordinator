using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ManufacturingCoordinator.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddBatchInventoryAndReporter : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ReportedByUserId",
                table: "DefectReports",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Batches",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    ProductType = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Batches", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "InventoryRolls",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    BatchId = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InventoryRolls", x => x.Id);
                    table.ForeignKey(
                        name: "FK_InventoryRolls_Batches_BatchId",
                        column: x => x.BatchId,
                        principalTable: "Batches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DefectReports_ReportedByUserId",
                table: "DefectReports",
                column: "ReportedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_InventoryRolls_BatchId_Status",
                table: "InventoryRolls",
                columns: new[] { "BatchId", "Status" });

            migrationBuilder.AddForeignKey(
                name: "FK_DefectReports_Users_ReportedByUserId",
                table: "DefectReports",
                column: "ReportedByUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DefectReports_Users_ReportedByUserId",
                table: "DefectReports");

            migrationBuilder.DropTable(
                name: "InventoryRolls");

            migrationBuilder.DropTable(
                name: "Batches");

            migrationBuilder.DropIndex(
                name: "IX_DefectReports_ReportedByUserId",
                table: "DefectReports");

            migrationBuilder.DropColumn(
                name: "ReportedByUserId",
                table: "DefectReports");
        }
    }
}
