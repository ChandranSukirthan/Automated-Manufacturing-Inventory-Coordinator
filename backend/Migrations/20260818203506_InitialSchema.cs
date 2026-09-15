using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ManufacturingCoordinator.Api.Migrations
{
    /// <inheritdoc />
    public partial class InitialSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Intentionally empty: the base schema is created by InitialCreate.
            // This migration was duplicated in the project and caused schema re-creation errors.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // No-op: no schema changes to reverse.
        }
    }
}
