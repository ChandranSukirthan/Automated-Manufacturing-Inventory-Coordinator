using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Authentication;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Models.Production;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Models.Inventory;
using ManufacturingCoordinator.Models.Quality;
using ManufacturingCoordinator.Api.Interfaces;
using RawMaterial = backend.Models.RawMaterial;

namespace ManufacturingCoordinator.Data
{
    public static class DbInitializer
    {
        public static async Task SeedAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var mfgDb = scope.ServiceProvider.GetRequiredService<backend.Data.ManufacturingContext>();
            var passwordHasher = scope.ServiceProvider.GetService<IPasswordHasher>();

            await EnsureProcurementTablesAsync(db);

            // 1. Seed Users for all roles
            var seedUsers = new[]
            {
                ("admin@amic.com", "System Admin", "Admin@123", UserRole.ITAdmin),
                ("worker@amic.com", "Floor Worker", "Worker@123", UserRole.FloorWorker),
                ("manager@amic.com", "Supply Chain Manager", "Manager@123", UserRole.SupplyChainManager),
                ("quality@amic.com", "Quality Inspector", "Quality@123", UserRole.QualityInspector)
            };

            foreach (var (email, name, pwd, role) in seedUsers)
            {
                var existing = await db.Users.FirstOrDefaultAsync(u => u.Email == email);
                var hash = passwordHasher != null ? passwordHasher.HashPassword(pwd) : pwd;
                if (existing != null)
                {
                    existing.FullName = name;
                    if (passwordHasher != null) existing.PasswordHash = hash;
                    existing.Role = role;
                    existing.IsEmailVerified = true;
                    existing.IsActive = true;
                    existing.UpdatedAt = DateTime.UtcNow;
                }
                else
                {
                    db.Users.Add(new User
                    {
                        FullName = name,
                        Email = email,
                        PasswordHash = hash,
                        Role = role,
                        IsEmailVerified = true,
                        IsActive = true
                    });
                }
            }
            await db.SaveChangesAsync();

            await SeedEntitiesAsync(db, mfgDb);
        }

        private static async Task SeedEntitiesAsync(ApplicationDbContext db, backend.Data.ManufacturingContext mfgDb)
        {
            await EnsureProcurementTablesAsync(db);

            // Seed RawMaterials
            if (!await db.RawMaterials.AnyAsync())
            {
                var materials = new List<RawMaterial>
                {
                    new()
                    {
                        Name = "Cold Rolled Steel Sheet",
                        SkuCode = "RM-STEEL-001",
                        Category = "Metal",
                        UnitOfMeasure = "KG",
                        Description = "1.5mm standard structural steel sheet",
                        ReorderThreshold = 200m,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    }
                };
                db.RawMaterials.AddRange(materials);
                await db.SaveChangesAsync();
            }

            // Seed Suppliers
            if (!await db.Suppliers.AnyAsync())
            {
                var suppliers = new List<Supplier>
                {
                    new()
                    {
                        SupplierName = "Global Steel Co.",
                        SupplierCode = "SUP-001",
                        ContactEmail = "sales@globalsteel.example.com",
                        ContactPhone = "+1-555-0101",
                        Address = "100 Metal Way, Industrial City",
                        PaymentTerms = "Net 30",
                        LeadTimeDays = 7,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    }
                };
                db.Suppliers.AddRange(suppliers);
                await db.SaveChangesAsync();
            }

        }

        private static async Task EnsureProcurementTablesAsync(ApplicationDbContext db)
        {
            if (!db.Database.IsRelational()) return;

            try
            {
                var sql = @"
                    CREATE TABLE IF NOT EXISTS ""ProcurementRequests"" (
                        ""Id"" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                        ""RawMaterialId"" integer NOT NULL,
                        ""RequiredSpecification"" character varying(200) NOT NULL,
                        ""ProductionRequirement"" numeric(18,3) NOT NULL,
                        ""CurrentStock"" numeric(18,3) NOT NULL,
                        ""SafetyStock"" numeric(18,3) NOT NULL,
                        ""ExistingOpenPoQuantity"" numeric(18,3) NOT NULL,
                        ""CalculatedNetQuantity"" numeric(18,3) NOT NULL,
                        ""MaximumBudget"" numeric(18,2) NOT NULL,
                        ""RequiredByDate"" timestamp with time zone NOT NULL,
                        ""QualityRequirement"" character varying(500) NOT NULL DEFAULT '',
                        ""PreferredRegion"" character varying(100),
                        ""Status"" text NOT NULL,
                        ""WorkflowId"" character varying(100),
                        ""MaterialName"" character varying(200),
                        ""RecommendedSupplierId"" integer,
                        ""GeneratedPurchaseOrderId"" integer,
                        ""FailureReason"" character varying(1000),
                        ""CreatedById"" uuid,
                        ""CreatedAt"" timestamp with time zone NOT NULL DEFAULT (timezone('utc', now())),
                        ""UpdatedAt"" timestamp with time zone NOT NULL DEFAULT (timezone('utc', now())),
                        CONSTRAINT ""FK_ProcurementRequests_RawMaterials_RawMaterialId"" FOREIGN KEY (""RawMaterialId"") REFERENCES ""RawMaterials"" (""Id"") ON DELETE RESTRICT,
                        CONSTRAINT ""FK_ProcurementRequests_Suppliers_RecommendedSupplierId"" FOREIGN KEY (""RecommendedSupplierId"") REFERENCES ""Suppliers"" (""Id"") ON DELETE SET NULL,
                        CONSTRAINT ""FK_ProcurementRequests_PurchaseOrders_GeneratedPurchaseOrderId"" FOREIGN KEY (""GeneratedPurchaseOrderId"") REFERENCES ""PurchaseOrders"" (""Id"") ON DELETE SET NULL,
                        CONSTRAINT ""FK_ProcurementRequests_Users_CreatedById"" FOREIGN KEY (""CreatedById"") REFERENCES ""Users"" (""Id"") ON DELETE SET NULL
                    );

                    CREATE TABLE IF NOT EXISTS ""SupplierCandidates"" (
                        ""Id"" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                        ""ProcurementRequestId"" integer NOT NULL,
                        ""SupplierId"" integer,
                        ""SupplierName"" character varying(200) NOT NULL,
                        ""MaterialName"" character varying(200) NOT NULL,
                        ""UnitPrice"" numeric(18,2) NOT NULL,
                        ""Currency"" character varying(10) NOT NULL DEFAULT 'USD',
                        ""MinimumOrderQuantity"" numeric(18,3) NOT NULL,
                        ""PackSize"" numeric(18,3) NOT NULL DEFAULT 1,
                        ""LeadTimeDays"" integer NOT NULL,
                        ""QualityEvidence"" character varying(500) NOT NULL DEFAULT '',
                        ""Availability"" character varying(100) NOT NULL DEFAULT 'In Stock',
                        ""SupplierStatus"" character varying(50) NOT NULL DEFAULT 'UNVERIFIED',
                        ""ConfidenceScore"" numeric(5,2) NOT NULL,
                        ""SourceUrl"" character varying(500),
                        ""IsValidated"" boolean NOT NULL,
                        ""ValidationRemarks"" character varying(1000),
                        ""RecommendedOrderQuantity"" numeric(18,3) NOT NULL,
                        ""TotalCost"" numeric(18,2) NOT NULL,
                        ""CreatedAt"" timestamp with time zone NOT NULL DEFAULT (timezone('utc', now())),
                        CONSTRAINT ""FK_SupplierCandidates_ProcurementRequests_ProcurementRequestId"" FOREIGN KEY (""ProcurementRequestId"") REFERENCES ""ProcurementRequests"" (""Id"") ON DELETE CASCADE,
                        CONSTRAINT ""FK_SupplierCandidates_Suppliers_SupplierId"" FOREIGN KEY (""SupplierId"") REFERENCES ""Suppliers"" (""Id"") ON DELETE SET NULL
                    );

                    ALTER TABLE ""ProcurementRequests"" ADD COLUMN IF NOT EXISTS ""WorkflowId"" character varying(100);
                    ALTER TABLE ""ProcurementRequests"" ADD COLUMN IF NOT EXISTS ""MaterialName"" character varying(200);
                    ALTER TABLE ""ProcurementRequests"" ADD COLUMN IF NOT EXISTS ""Priority"" character varying(50) DEFAULT 'Normal';
                    ALTER TABLE ""SupplierCandidates"" ADD COLUMN IF NOT EXISTS ""Availability"" character varying(100) DEFAULT 'In Stock';

                    -- Ensure StockAlerts procurement columns exist
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""MaterialId"" integer;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""MaterialName"" character varying(200);
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""CurrentStock"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""RequiredQuantity"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""SafetyStock"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""OpenPurchaseQuantity"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""NetDeficit"" numeric(18,3) NOT NULL DEFAULT 0;
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""Severity"" character varying(50) DEFAULT 'Medium';
                    ALTER TABLE ""StockAlerts"" ADD COLUMN IF NOT EXISTS ""IsRead"" boolean NOT NULL DEFAULT false;

                    -- Ensure PurchaseOrders tracking and delivery columns exist
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""ProcurementRequestId"" integer;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""TrackingStatus"" character varying(50) DEFAULT 'Draft';
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""ExpectedDeliveryDate"" timestamp with time zone;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""ActualDeliveryDate"" timestamp with time zone;
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""TrackingNumber"" character varying(200);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""DeliveryRemarks"" character varying(500);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""BankSlipUrl"" character varying(500);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""BankReferenceNumber"" character varying(100);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""BankSlipStatus"" character varying(50);
                    ALTER TABLE ""PurchaseOrders"" ADD COLUMN IF NOT EXISTS ""BankSlipUploadedAt"" timestamp with time zone;

                    CREATE TABLE IF NOT EXISTS ""ProcurementOutcomes"" (
                        ""Id"" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                        ""Material"" character varying(200) NOT NULL,
                        ""RequestedQuantity"" numeric(18,3) NOT NULL,
                        ""RecommendedQuantity"" numeric(18,3) NOT NULL,
                        ""FinalOrderedQuantity"" numeric(18,3) NOT NULL,
                        ""RecommendedSupplier"" character varying(200) NOT NULL,
                        ""SelectedSupplier"" character varying(200) NOT NULL,
                        ""EstimatedPrice"" numeric(18,2) NOT NULL,
                        ""FinalPrice"" numeric(18,2) NOT NULL,
                        ""EstimatedLeadTime"" integer NOT NULL,
                        ""ActualLeadTime"" integer NOT NULL,
                        ""QualityEvidence"" character varying(1000) NOT NULL DEFAULT '',
                        ""SupplierVerification"" character varying(100) NOT NULL DEFAULT 'VERIFIED',
                        ""ManagerDecision"" character varying(100) NOT NULL,
                        ""ManagerRevision"" character varying(1000),
                        ""ProcurementSuccess"" boolean NOT NULL DEFAULT true,
                        ""PaymentSuccess"" boolean NOT NULL DEFAULT true,
                        ""DeliverySuccess"" boolean NOT NULL DEFAULT false,
                        ""QualityOutcome"" character varying(500),
                        ""CreatedAt"" timestamp with time zone NOT NULL DEFAULT (timezone('utc', now())),
                        ""CompletedAt"" timestamp with time zone,
                        ""PurchaseOrderId"" integer,
                        ""ProcurementRequestId"" integer
                    );
                ";
                await db.Database.ExecuteSqlRawAsync(sql);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Procurement tables creation/check notice: {ex.Message}");
            }
        }
    }
}
