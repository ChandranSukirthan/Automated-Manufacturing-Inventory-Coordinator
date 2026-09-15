using Microsoft.EntityFrameworkCore.Migrations;
using ManufacturingCoordinator.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

#nullable disable

namespace ManufacturingCoordinator.Api.Migrations
{
    [Migration("20260915120000_AddAffectedInventoryToDefectReports")]
    [DbContext(typeof(ApplicationDbContext))]
    public partial class AddAffectedInventoryToDefectReports : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AffectedInventoryJson",
                table: "DefectReports",
                type: "text",
                nullable: false,
                defaultValue: "[]");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AffectedInventoryJson",
                table: "DefectReports");
        }
    }
}