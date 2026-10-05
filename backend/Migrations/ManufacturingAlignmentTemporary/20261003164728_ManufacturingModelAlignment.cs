using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace ManufacturingCoordinator.Api.Migrations.ManufacturingAlignmentTemporary
{
    /// <inheritdoc />
    public partial class ManufacturingModelAlignment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_InventoryRolls_RawMaterials_RawMaterialId",
                table: "InventoryRolls");

            migrationBuilder.AlterColumn<string>(
                name: "SkuCode",
                table: "RawMaterials",
                type: "character varying(255)",
                maxLength: 255,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(50)",
                oldMaxLength: 50);

            migrationBuilder.AddColumn<string>(
                name: "MaterialCode",
                table: "RawMaterials",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "PackagingTypeId",
                table: "RawMaterials",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "InventoryRolls",
                type: "integer",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "text")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AddColumn<int>(
                name: "PackagingTypeId",
                table: "InventoryItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RawMaterialId",
                table: "InventoryItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SkuNumber",
                table: "InventoryItems",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "InventoryMovements",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    RawMaterialId = table.Column<int>(type: "integer", nullable: false),
                    RollIdentifier = table.Column<string>(type: "text", nullable: false),
                    TransactionType = table.Column<string>(type: "text", nullable: false),
                    Quantity = table.Column<decimal>(type: "numeric", nullable: false),
                    PreviousStock = table.Column<decimal>(type: "numeric", nullable: false),
                    NewStock = table.Column<decimal>(type: "numeric", nullable: false),
                    Reason = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InventoryMovements", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PackagingTypes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ShortCode = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PackagingTypes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RawMaterials_PackagingTypeId_MaterialCode",
                table: "RawMaterials",
                columns: new[] { "PackagingTypeId", "MaterialCode" });

            migrationBuilder.CreateIndex(
                name: "IX_InventoryItems_Sku",
                table: "InventoryItems",
                column: "Sku",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PackagingTypes_Name",
                table: "PackagingTypes",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PackagingTypes_ShortCode",
                table: "PackagingTypes",
                column: "ShortCode",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_InventoryRolls_RawMaterials_RawMaterialId",
                table: "InventoryRolls",
                column: "RawMaterialId",
                principalTable: "RawMaterials",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_RawMaterials_PackagingTypes_PackagingTypeId",
                table: "RawMaterials",
                column: "PackagingTypeId",
                principalTable: "PackagingTypes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_InventoryRolls_RawMaterials_RawMaterialId",
                table: "InventoryRolls");

            migrationBuilder.DropForeignKey(
                name: "FK_RawMaterials_PackagingTypes_PackagingTypeId",
                table: "RawMaterials");

            migrationBuilder.DropTable(
                name: "InventoryMovements");

            migrationBuilder.DropTable(
                name: "PackagingTypes");

            migrationBuilder.DropIndex(
                name: "IX_RawMaterials_PackagingTypeId_MaterialCode",
                table: "RawMaterials");

            migrationBuilder.DropIndex(
                name: "IX_InventoryItems_Sku",
                table: "InventoryItems");

            migrationBuilder.DropColumn(
                name: "MaterialCode",
                table: "RawMaterials");

            migrationBuilder.DropColumn(
                name: "PackagingTypeId",
                table: "RawMaterials");

            migrationBuilder.DropColumn(
                name: "PackagingTypeId",
                table: "InventoryItems");

            migrationBuilder.DropColumn(
                name: "RawMaterialId",
                table: "InventoryItems");

            migrationBuilder.DropColumn(
                name: "SkuNumber",
                table: "InventoryItems");

            migrationBuilder.AlterColumn<string>(
                name: "SkuCode",
                table: "RawMaterials",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(255)",
                oldMaxLength: 255);

            migrationBuilder.AlterColumn<string>(
                name: "Id",
                table: "InventoryRolls",
                type: "text",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer")
                .OldAnnotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AddForeignKey(
                name: "FK_InventoryRolls_RawMaterials_RawMaterialId",
                table: "InventoryRolls",
                column: "RawMaterialId",
                principalTable: "RawMaterials",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
