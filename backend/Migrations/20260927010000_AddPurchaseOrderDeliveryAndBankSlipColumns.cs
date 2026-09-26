using System;
using Microsoft.EntityFrameworkCore.Migrations;
using ManufacturingCoordinator.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;

#nullable disable

namespace ManufacturingCoordinator.Api.Migrations
{
    [Migration("20260927010000_AddPurchaseOrderDeliveryAndBankSlipColumns")]
    [DbContext(typeof(ApplicationDbContext))]
    public partial class AddPurchaseOrderDeliveryAndBankSlipColumns : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ProcurementRequestId",
                table: "PurchaseOrders",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TrackingStatus",
                table: "PurchaseOrders",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "Draft");

            migrationBuilder.AddColumn<DateTime>(
                name: "ExpectedDeliveryDate",
                table: "PurchaseOrders",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ActualDeliveryDate",
                table: "PurchaseOrders",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TrackingNumber",
                table: "PurchaseOrders",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryRemarks",
                table: "PurchaseOrders",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankSlipUrl",
                table: "PurchaseOrders",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankReferenceNumber",
                table: "PurchaseOrders",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankSlipStatus",
                table: "PurchaseOrders",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "BankSlipUploadedAt",
                table: "PurchaseOrders",
                type: "timestamp with time zone",
                nullable: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "ProcurementRequestId", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "TrackingStatus", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "ExpectedDeliveryDate", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "ActualDeliveryDate", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "TrackingNumber", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "DeliveryRemarks", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "BankSlipUrl", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "BankReferenceNumber", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "BankSlipStatus", table: "PurchaseOrders");
            migrationBuilder.DropColumn(name: "BankSlipUploadedAt", table: "PurchaseOrders");
        }
    }
}
