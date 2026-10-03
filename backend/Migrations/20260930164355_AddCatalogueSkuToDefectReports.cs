using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ManufacturingCoordinator.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCatalogueSkuToDefectReports : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "SkuCode",
                table: "DefectReports",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_DefectReports_SkuCode",
                table: "DefectReports",
                column: "SkuCode");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_DefectReports_SkuCode",
                table: "DefectReports");

            migrationBuilder.DropColumn(
                name: "SkuCode",
                table: "DefectReports");
        }
    }
}
