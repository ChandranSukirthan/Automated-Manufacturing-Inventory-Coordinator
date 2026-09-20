using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ManufacturingCoordinator.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddQuarantineManagement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Quarantines",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    DefectReportId = table.Column<Guid>(type: "uuid", nullable: false),
                    InventoryRollId = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Reason = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false, defaultValue: "Active"),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "timezone('utc', now())"),
                    ReleasedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Quarantines", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Quarantines_DefectReports_DefectReportId",
                        column: x => x.DefectReportId,
                        principalTable: "DefectReports",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Quarantines_DefectReportId",
                table: "Quarantines",
                column: "DefectReportId");

            migrationBuilder.CreateIndex(
                name: "IX_Quarantines_InventoryRollId_Status",
                table: "Quarantines",
                columns: new[] { "InventoryRollId", "Status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Quarantines");
        }
    }
}
