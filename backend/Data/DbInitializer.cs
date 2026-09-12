using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.PurchaseOrders;
using backend.Models;

namespace ManufacturingCoordinator.Data
{
    public static class DbInitializer
    {
        public static async Task SeedAsync(ApplicationDbContext context)
        {
            // 1. Seed RawMaterials if table is empty
            if (!await context.RawMaterials.AnyAsync())
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
                    },
                    new()
                    {
                        Name = "High-Tensile Aluminum Rod",
                        SkuCode = "RM-ALUM-002",
                        Category = "Metal",
                        UnitOfMeasure = "METRES",
                        Description = "6061-T6 aviation grade aluminum rod",
                        ReorderThreshold = 100m,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    },
                    new()
                    {
                        Name = "Industrial Polypropylene Pellets",
                        SkuCode = "RM-POLY-003",
                        Category = "Polymer",
                        UnitOfMeasure = "KG",
                        Description = "High-impact injection molding grade polymer",
                        ReorderThreshold = 1000m,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    }
                };

                context.RawMaterials.AddRange(materials);
                await context.SaveChangesAsync();
            }

            // 2. Seed Suppliers if empty
            if (!await context.Suppliers.AnyAsync())
            {
                var suppliers = new List<Supplier>
                {
                    new()
                    {
                        SupplierCode = "SUP-001",
                        Name = "Apex Industrial Metals",
                        ContactEmail = "orders@apeximetals.com",
                        ContactPhone = "+1-555-0192",
                        Address = "100 Industrial Parkway, Chicago, IL",
                        PaymentTerms = "Net 30",
                        LeadTimeDays = 7,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow.AddDays(-60),
                        UpdatedAt = DateTime.UtcNow.AddDays(-60)
                    },
                    new()
                    {
                        SupplierCode = "SUP-002",
                        Name = "Global Precision Fasteners",
                        ContactEmail = "procurement@globalfasteners.com",
                        ContactPhone = "+1-555-0283",
                        Address = "450 Logistics Way, Detroit, MI",
                        PaymentTerms = "Net 60",
                        LeadTimeDays = 14,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow.AddDays(-45),
                        UpdatedAt = DateTime.UtcNow.AddDays(-45)
                    },
                    new()
                    {
                        SupplierCode = "SUP-003",
                        Name = "Polymer & Composites Direct",
                        ContactEmail = "sales@polymerdirect.com",
                        ContactPhone = "+1-555-0374",
                        Address = "78 Polymer Row, Akron, OH",
                        PaymentTerms = "Net 30",
                        LeadTimeDays = 10,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow.AddDays(-30),
                        UpdatedAt = DateTime.UtcNow.AddDays(-30)
                    }
                };

                context.Suppliers.AddRange(suppliers);
                await context.SaveChangesAsync();
            }

            // 3. Seed Purchase Orders with Order Lines if none exist
            if (!await context.PurchaseOrders.AnyAsync())
            {
                var supplier1 = await context.Suppliers.FirstOrDefaultAsync(s => s.SupplierCode == "SUP-001");
                var supplier2 = await context.Suppliers.FirstOrDefaultAsync(s => s.SupplierCode == "SUP-002");
                var material1 = await context.RawMaterials.FirstOrDefaultAsync();

                if (supplier1 != null && material1 != null)
                {
                    // Seed a historical completed PO
                    var po1 = new PurchaseOrder
                    {
                        PoNumber = "PO-2026-0001",
                        SupplierId = supplier1.Id,
                        Currency = "USD",
                        Status = PurchaseOrderStatus.Sent,
                        BudgetLimit = 10000m,
                        ApprovalThreshold = 5000m,
                        RequiresApproval = true,
                        TotalCost = 6750m,
                        Notes = "Q1 replenishment order",
                        StripePaymentIntentId = "pi_mock_seed_001",
                        StripePaymentStatus = "succeeded",
                        EmailStatus = "Sent",
                        EmailSentAt = DateTime.UtcNow.AddDays(-10),
                        CreatedAt = DateTime.UtcNow.AddDays(-15),
                        UpdatedAt = DateTime.UtcNow.AddDays(-10),
                        OrderLines = new List<OrderLine>
                        {
                            new()
                            {
                                RawMaterialId = material1.Id,
                                Description = "Batch 1 Steel Sheets",
                                Quantity = 1500m,
                                UnitPrice = 4.50m,
                                TotalPrice = 6750m,
                                CreatedAt = DateTime.UtcNow.AddDays(-15),
                                UpdatedAt = DateTime.UtcNow.AddDays(-15)
                            }
                        }
                    };

                    context.PurchaseOrders.Add(po1);
                    await context.SaveChangesAsync();

                    // Seed an approval audit
                    context.PurchaseOrderApprovals.Add(new PurchaseOrderApproval
                    {
                        PurchaseOrderId = po1.Id,
                        Action = "PO approved",
                        UserName = "Supply Chain Manager",
                        Notes = "Approved initial stock order",
                        Timestamp = DateTime.UtcNow.AddDays(-10)
                    });

                    // Seed a payment transaction
                    context.PaymentTransactions.Add(new PaymentTransaction
                    {
                        PurchaseOrderId = po1.Id,
                        TransactionId = "pi_mock_seed_001",
                        Amount = 6750m,
                        Currency = "usd",
                        PaymentStatus = "succeeded",
                        Timestamp = DateTime.UtcNow.AddDays(-10)
                    });

                    await context.SaveChangesAsync();
                }

                if (supplier2 != null && material1 != null)
                {
                    // Seed a pending approval PO for manager review ($9,000 > $5,000 threshold)
                    var po2 = new PurchaseOrder
                    {
                        PoNumber = "PO-2026-0002",
                        SupplierId = supplier2.Id,
                        Currency = "USD",
                        Status = PurchaseOrderStatus.PendingApproval,
                        BudgetLimit = 15000m,
                        ApprovalThreshold = 5000m,
                        RequiresApproval = true,
                        TotalCost = 9000m,
                        Notes = "AI Recommended: High burn rate forecast requires urgent steel coils.",
                        CreatedAt = DateTime.UtcNow.AddHours(-2),
                        UpdatedAt = DateTime.UtcNow.AddHours(-1),
                        OrderLines = new List<OrderLine>
                        {
                            new()
                            {
                                RawMaterialId = material1.Id,
                                Description = "High-volume steel coil replenishment",
                                Quantity = 2000m,
                                UnitPrice = 4.50m,
                                TotalPrice = 9000m,
                                CreatedAt = DateTime.UtcNow.AddHours(-2),
                                UpdatedAt = DateTime.UtcNow.AddHours(-2)
                            }
                        }
                    };

                    context.PurchaseOrders.Add(po2);
                    await context.SaveChangesAsync();

                    context.PurchaseOrderApprovals.Add(new PurchaseOrderApproval
                    {
                        PurchaseOrderId = po2.Id,
                        Action = "PO submitted",
                        UserName = "System Auto-Coordinator",
                        Notes = "Submitted by AI inventory monitoring service",
                        Timestamp = DateTime.UtcNow.AddHours(-1)
                    });

                    await context.SaveChangesAsync();
                }
            }
        }
    }
}
