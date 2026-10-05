using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace ManufacturingCoordinator.Api.Migrations.AlignmentTemporary
{
    /// <inheritdoc />
    public partial class IntegrationModelAlignment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_InventoryRoll_RawMaterials_RawMaterialId",
                table: "InventoryRoll");

            migrationBuilder.DropForeignKey(
                name: "FK_StockLevel_RawMaterials_RawMaterialId",
                table: "StockLevel");

            migrationBuilder.DropPrimaryKey(
                name: "PK_StockLevel",
                table: "StockLevel");

            migrationBuilder.DropPrimaryKey(
                name: "PK_InventoryRoll",
                table: "InventoryRoll");

            migrationBuilder.RenameTable(
                name: "StockLevel",
                newName: "StockLevels");

            migrationBuilder.RenameTable(
                name: "InventoryRoll",
                newName: "InventoryRolls");

            migrationBuilder.RenameIndex(
                name: "IX_StockLevel_RawMaterialId",
                table: "StockLevels",
                newName: "IX_StockLevels_RawMaterialId");

            migrationBuilder.RenameIndex(
                name: "IX_InventoryRoll_RawMaterialId",
                table: "InventoryRolls",
                newName: "IX_InventoryRolls_RawMaterialId");

            migrationBuilder.AddColumn<DateTime>(
                name: "ActualDeliveryDate",
                table: "PurchaseOrders",
                type: "timestamp with time zone",
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

            migrationBuilder.AddColumn<string>(
                name: "BankSlipUrl",
                table: "PurchaseOrders",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryRemarks",
                table: "PurchaseOrders",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ExpectedDeliveryDate",
                table: "PurchaseOrders",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsAcknowledgedByScm",
                table: "PurchaseOrders",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "IsFinancialVerified",
                table: "PurchaseOrders",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "IsQualityVerified",
                table: "PurchaseOrders",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "ProcurementRequestId",
                table: "PurchaseOrders",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TrackingNumber",
                table: "PurchaseOrders",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TrackingStatus",
                table: "PurchaseOrders",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "Draft");

            migrationBuilder.AddColumn<Guid>(
                name: "MachineId",
                table: "AgentWorkflows",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PurchaseOrderId",
                table: "AgentWorkflows",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StateJson",
                table: "AgentWorkflows",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ValidationResults",
                table: "AgentWorkflows",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WorkflowType",
                table: "AgentWorkflows",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "BatchId",
                table: "InventoryRolls",
                type: "text",
                nullable: true);

            migrationBuilder.AddPrimaryKey(
                name: "PK_StockLevels",
                table: "StockLevels",
                column: "Id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_InventoryRolls",
                table: "InventoryRolls",
                column: "Id");

            migrationBuilder.CreateTable(
                name: "GoodsReceipts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PurchaseOrderId = table.Column<int>(type: "integer", nullable: false),
                    OrderLineId = table.Column<int>(type: "integer", nullable: false),
                    ReceiptKey = table.Column<string>(type: "text", nullable: false),
                    RollIdentifier = table.Column<string>(type: "text", nullable: false),
                    BatchId = table.Column<string>(type: "text", nullable: false),
                    Quantity = table.Column<decimal>(type: "numeric", nullable: false),
                    ReceivedById = table.Column<Guid>(type: "uuid", nullable: true),
                    ReceivedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GoodsReceipts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "InventoryItems",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Sku = table.Column<string>(type: "text", nullable: false),
                    Name = table.Column<string>(type: "text", nullable: false),
                    Category = table.Column<string>(type: "text", nullable: false),
                    PackagingTypeId = table.Column<int>(type: "integer", nullable: true),
                    RawMaterialId = table.Column<int>(type: "integer", nullable: true),
                    SkuNumber = table.Column<int>(type: "integer", nullable: true),
                    StockLevel = table.Column<int>(type: "integer", nullable: false),
                    ReorderThreshold = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InventoryItems", x => x.Id);
                });

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
                name: "ProcurementOutcomes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Material = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    RequestedQuantity = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    RecommendedQuantity = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    FinalOrderedQuantity = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    RecommendedSupplier = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    SelectedSupplier = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    EstimatedPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    FinalPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    EstimatedLeadTime = table.Column<int>(type: "integer", nullable: false),
                    ActualLeadTime = table.Column<int>(type: "integer", nullable: false),
                    QualityEvidence = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    SupplierVerification = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ManagerDecision = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ManagerRevision = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    ProcurementSuccess = table.Column<bool>(type: "boolean", nullable: false),
                    PaymentSuccess = table.Column<bool>(type: "boolean", nullable: false),
                    DeliverySuccess = table.Column<bool>(type: "boolean", nullable: false),
                    QualityOutcome = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "timezone('utc', now())"),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    PurchaseOrderId = table.Column<int>(type: "integer", nullable: true),
                    ProcurementRequestId = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProcurementOutcomes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ProcurementRequests",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    RawMaterialId = table.Column<int>(type: "integer", nullable: false),
                    RequiredSpecification = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    ProductionRequirement = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    CurrentStock = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    SafetyStock = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    ExistingOpenPoQuantity = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    CalculatedNetQuantity = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    MaximumBudget = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    RequiredByDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    QualityRequirement = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    PreferredRegion = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Status = table.Column<string>(type: "text", nullable: false),
                    WorkflowId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    MaterialName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    RecommendedSupplierId = table.Column<int>(type: "integer", nullable: true),
                    GeneratedPurchaseOrderId = table.Column<int>(type: "integer", nullable: true),
                    FailureReason = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    CreatedById = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "timezone('utc', now())"),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "timezone('utc', now())"),
                    Priority = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProcurementRequests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProcurementRequests_PurchaseOrders_GeneratedPurchaseOrderId",
                        column: x => x.GeneratedPurchaseOrderId,
                        principalTable: "PurchaseOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ProcurementRequests_RawMaterials_RawMaterialId",
                        column: x => x.RawMaterialId,
                        principalTable: "RawMaterials",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ProcurementRequests_Suppliers_RecommendedSupplierId",
                        column: x => x.RecommendedSupplierId,
                        principalTable: "Suppliers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ProcurementRequests_Users_CreatedById",
                        column: x => x.CreatedById,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "StockAlerts",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Sku = table.Column<string>(type: "text", nullable: false),
                    PackagingType = table.Column<string>(type: "text", nullable: false),
                    QuantityRequested = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    Timestamp = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    WorkerId = table.Column<string>(type: "text", nullable: false),
                    MaterialId = table.Column<int>(type: "integer", nullable: true),
                    MaterialName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CurrentStock = table.Column<decimal>(type: "numeric", nullable: false),
                    RequiredQuantity = table.Column<decimal>(type: "numeric", nullable: false),
                    SafetyStock = table.Column<decimal>(type: "numeric", nullable: false),
                    OpenPurchaseQuantity = table.Column<decimal>(type: "numeric", nullable: false),
                    NetDeficit = table.Column<decimal>(type: "numeric", nullable: false),
                    Severity = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    IsRead = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockAlerts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SupplierMaterialQuotes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    SupplierId = table.Column<int>(type: "integer", nullable: false),
                    RawMaterialId = table.Column<int>(type: "integer", nullable: false),
                    UnitPrice = table.Column<decimal>(type: "numeric", nullable: false),
                    MinimumOrderQuantity = table.Column<decimal>(type: "numeric", nullable: false),
                    PackSize = table.Column<decimal>(type: "numeric", nullable: false),
                    AvailableQuantity = table.Column<decimal>(type: "numeric", nullable: false),
                    LeadTimeDays = table.Column<int>(type: "integer", nullable: false),
                    QualityEvidence = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Currency = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplierMaterialQuotes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SupplierCandidates",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    ProcurementRequestId = table.Column<int>(type: "integer", nullable: false),
                    SupplierId = table.Column<int>(type: "integer", nullable: true),
                    SupplierName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    MaterialName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    UnitPrice = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    Currency = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false, defaultValue: "USD"),
                    MinimumOrderQuantity = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    PackSize = table.Column<decimal>(type: "numeric(18,3)", nullable: false, defaultValue: 1m),
                    LeadTimeDays = table.Column<int>(type: "integer", nullable: false),
                    QualityEvidence = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Availability = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false, defaultValue: "In Stock"),
                    SupplierStatus = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false, defaultValue: "UNVERIFIED"),
                    ConfidenceScore = table.Column<decimal>(type: "numeric(5,2)", nullable: false),
                    SourceUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    IsValidated = table.Column<bool>(type: "boolean", nullable: false),
                    ValidationRemarks = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    RecommendedOrderQuantity = table.Column<decimal>(type: "numeric(18,3)", nullable: false),
                    TotalCost = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "timezone('utc', now())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplierCandidates", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SupplierCandidates_ProcurementRequests_ProcurementRequestId",
                        column: x => x.ProcurementRequestId,
                        principalTable: "ProcurementRequests",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SupplierCandidates_Suppliers_SupplierId",
                        column: x => x.SupplierId,
                        principalTable: "Suppliers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_InventoryRolls_RollIdentifier",
                table: "InventoryRolls",
                column: "RollIdentifier",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GoodsReceipts_ReceiptKey",
                table: "GoodsReceipts",
                column: "ReceiptKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_InventoryItems_Sku",
                table: "InventoryItems",
                column: "Sku",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ProcurementRequests_CreatedById",
                table: "ProcurementRequests",
                column: "CreatedById");

            migrationBuilder.CreateIndex(
                name: "IX_ProcurementRequests_GeneratedPurchaseOrderId",
                table: "ProcurementRequests",
                column: "GeneratedPurchaseOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_ProcurementRequests_RawMaterialId",
                table: "ProcurementRequests",
                column: "RawMaterialId");

            migrationBuilder.CreateIndex(
                name: "IX_ProcurementRequests_RecommendedSupplierId",
                table: "ProcurementRequests",
                column: "RecommendedSupplierId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplierCandidates_ProcurementRequestId",
                table: "SupplierCandidates",
                column: "ProcurementRequestId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplierCandidates_SupplierId",
                table: "SupplierCandidates",
                column: "SupplierId");

            migrationBuilder.AddForeignKey(
                name: "FK_InventoryRolls_RawMaterials_RawMaterialId",
                table: "InventoryRolls",
                column: "RawMaterialId",
                principalTable: "RawMaterials",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_StockLevels_RawMaterials_RawMaterialId",
                table: "StockLevels",
                column: "RawMaterialId",
                principalTable: "RawMaterials",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_InventoryRolls_RawMaterials_RawMaterialId",
                table: "InventoryRolls");

            migrationBuilder.DropForeignKey(
                name: "FK_StockLevels_RawMaterials_RawMaterialId",
                table: "StockLevels");

            migrationBuilder.DropTable(
                name: "GoodsReceipts");

            migrationBuilder.DropTable(
                name: "InventoryItems");

            migrationBuilder.DropTable(
                name: "InventoryMovements");

            migrationBuilder.DropTable(
                name: "ProcurementOutcomes");

            migrationBuilder.DropTable(
                name: "StockAlerts");

            migrationBuilder.DropTable(
                name: "SupplierCandidates");

            migrationBuilder.DropTable(
                name: "SupplierMaterialQuotes");

            migrationBuilder.DropTable(
                name: "ProcurementRequests");

            migrationBuilder.DropPrimaryKey(
                name: "PK_StockLevels",
                table: "StockLevels");

            migrationBuilder.DropPrimaryKey(
                name: "PK_InventoryRolls",
                table: "InventoryRolls");

            migrationBuilder.DropIndex(
                name: "IX_InventoryRolls_RollIdentifier",
                table: "InventoryRolls");

            migrationBuilder.DropColumn(
                name: "ActualDeliveryDate",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "BankReferenceNumber",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "BankSlipStatus",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "BankSlipUploadedAt",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "BankSlipUrl",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "DeliveryRemarks",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "ExpectedDeliveryDate",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "IsAcknowledgedByScm",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "IsFinancialVerified",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "IsQualityVerified",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "ProcurementRequestId",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "TrackingNumber",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "TrackingStatus",
                table: "PurchaseOrders");

            migrationBuilder.DropColumn(
                name: "MachineId",
                table: "AgentWorkflows");

            migrationBuilder.DropColumn(
                name: "PurchaseOrderId",
                table: "AgentWorkflows");

            migrationBuilder.DropColumn(
                name: "StateJson",
                table: "AgentWorkflows");

            migrationBuilder.DropColumn(
                name: "ValidationResults",
                table: "AgentWorkflows");

            migrationBuilder.DropColumn(
                name: "WorkflowType",
                table: "AgentWorkflows");

            migrationBuilder.DropColumn(
                name: "BatchId",
                table: "InventoryRolls");

            migrationBuilder.RenameTable(
                name: "StockLevels",
                newName: "StockLevel");

            migrationBuilder.RenameTable(
                name: "InventoryRolls",
                newName: "InventoryRoll");

            migrationBuilder.RenameIndex(
                name: "IX_StockLevels_RawMaterialId",
                table: "StockLevel",
                newName: "IX_StockLevel_RawMaterialId");

            migrationBuilder.RenameIndex(
                name: "IX_InventoryRolls_RawMaterialId",
                table: "InventoryRoll",
                newName: "IX_InventoryRoll_RawMaterialId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_StockLevel",
                table: "StockLevel",
                column: "Id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_InventoryRoll",
                table: "InventoryRoll",
                column: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_InventoryRoll_RawMaterials_RawMaterialId",
                table: "InventoryRoll",
                column: "RawMaterialId",
                principalTable: "RawMaterials",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_StockLevel_RawMaterials_RawMaterialId",
                table: "StockLevel",
                column: "RawMaterialId",
                principalTable: "RawMaterials",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
