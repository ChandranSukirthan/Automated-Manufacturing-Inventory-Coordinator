using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Api.Interfaces;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Services.PurchaseOrders;
using backend.Models;

namespace backend.Tests
{
    public class PurchaseOrderTests
    {
        private ApplicationDbContext CreateInMemoryDbContext()
        {
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            var context = new ApplicationDbContext(options);
            context.Database.EnsureCreated();

            // Seed a raw material for test order lines
            context.RawMaterials.Add(new RawMaterial
            {
                Id = 1,
                Name = "High Grade Steel",
                SkuCode = "RM-STEEL-01",
                Category = "Metal",
                UnitOfMeasure = "KG",
                ReorderThreshold = 500m,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });
            context.SaveChanges();

            return context;
        }

        private IConfiguration CreateTestConfiguration(decimal threshold = 5000m)
        {
            var myConfiguration = new Dictionary<string, string>
            {
                { "PurchaseOrderSettings:ApprovalThresholdAmount", threshold.ToString() },
                { "PurchaseOrderSettings:PoNumberPrefix", "PO" }
            };

            return new ConfigurationBuilder()
                .AddInMemoryCollection(myConfiguration!)
                .Build();
        }

        // =========================================================================
        // 1. SUPPLIER CRUD TESTS
        // =========================================================================

        [Fact]
        public async Task SupplierCRUD_CreateReadUpdateSoftDelete_WorksCorrectly()
        {
            using var context = CreateInMemoryDbContext();
            var supplierService = new SupplierService(context);

            // 1. Create
            var createDto = new CreateSupplierDto
            {
                Name = "Acme Raw Materials",
                ContactEmail = "orders@acme.com",
                ContactPhone = "123-456-7890",
                Address = "100 Industrial Blvd"
            };
            var created = await supplierService.CreateAsync(createDto);
            Assert.NotNull(created);
            Assert.Equal("Acme Raw Materials", created.Name);
            Assert.Equal("orders@acme.com", created.ContactEmail);
            Assert.True(created.IsActive);

            // 2. Read (GetById and GetAll)
            var retrieved = await supplierService.GetByIdAsync(created.Id);
            Assert.NotNull(retrieved);
            Assert.Equal(created.Id, retrieved.Id);

            var all = await supplierService.GetAllAsync();
            Assert.Single(all);

            // 3. Update
            var updateDto = new UpdateSupplierDto
            {
                Name = "Acme Global Materials",
                ContactEmail = "global@acme.com",
                ContactPhone = "999-888-7777",
                Address = "200 Global Way",
                IsActive = true
            };
            var updated = await supplierService.UpdateAsync(created.Id, updateDto);
            Assert.NotNull(updated);
            Assert.Equal("Acme Global Materials", updated.Name);
            Assert.Equal("global@acme.com", updated.ContactEmail);

            // 4. Soft Delete
            var deleted = await supplierService.DeleteAsync(created.Id);
            Assert.True(deleted);

            var softDeleted = await supplierService.GetByIdAsync(created.Id);
            Assert.NotNull(softDeleted);
            Assert.False(softDeleted.IsActive); // Preserved with IsActive = false
        }

        // =========================================================================
        // 2. PURCHASE ORDER CRUD & DRAFT EDIT RESTRICTION
        // =========================================================================

        [Fact]
        public async Task PurchaseOrder_CreateAndRead_CalculatesDetailsCorrectly()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier
            {
                Name = "Apex Supplies",
                ContactEmail = "orders@apex.com",
                IsActive = true
            };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            var emailMock = new Mock<IEmailService>();
            var config = CreateTestConfiguration(5000m);
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var createDto = new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 10000m,
                Notes = "Urgent replenishment",
                Lines = new List<OrderLineDto>
                {
                    new OrderLineDto { RawMaterialId = 1, Description = "Steel Rods", Quantity = 100, UnitPrice = 15m }
                }
            };

            var po = await poService.CreateAsync(createDto);
            Assert.NotNull(po);
            Assert.Equal("Draft", po.Status);
            Assert.Equal(1500m, po.TotalCost);
            Assert.False(po.RequiresApproval); // Below 5000 threshold
            Assert.Single(po.OrderLines);
            Assert.Equal("Steel Rods", po.OrderLines[0].Description);
        }

        [Fact]
        public async Task PurchaseOrder_UpdateWhenNotInDraft_ThrowsInvalidOperationException()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "Apex", ContactEmail = "orders@apex.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            var emailMock = new Mock<IEmailService>();
            var config = CreateTestConfiguration(5000m);
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var po = await poService.CreateAsync(new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 10000m,
                Lines = new List<OrderLineDto>
                {
                    new OrderLineDto { RawMaterialId = 1, Quantity = 10, UnitPrice = 20m }
                }
            });

            // Transition out of Draft to PendingApproval
            await poService.SubmitForApprovalAsync(po.Id);

            // Attempting to update should throw
            await Assert.ThrowsAsync<InvalidOperationException>(async () =>
            {
                await poService.UpdateAsync(po.Id, new UpdatePurchaseOrderDto
                {
                    SupplierId = supplier.Id,
                    BudgetLimit = 10000m,
                    Lines = new List<OrderLineDto>
                    {
                        new OrderLineDto { RawMaterialId = 1, Quantity = 20, UnitPrice = 20m }
                    }
                });
            });
        }

        // =========================================================================
        // 3. TOTAL CALCULATION (Example: Qty = 2000, UnitPrice = $4.50 -> $9,000)
        // =========================================================================

        [Fact]
        public async Task CalculateTotalCost_Quantity2000_UnitPrice4Point50_Returns9000()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "SteelWorks", ContactEmail = "sw@test.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            var emailMock = new Mock<IEmailService>();
            var config = CreateTestConfiguration(5000m);
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var createDto = new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 15000m,
                Lines = new List<OrderLineDto>
                {
                    new OrderLineDto
                    {
                        RawMaterialId = 1,
                        Description = "Raw Steel Coils",
                        Quantity = 2000m,
                        UnitPrice = 4.50m
                    }
                }
            };

            var po = await poService.CreateAsync(createDto);

            // Verified exact calculation: 2000 * 4.50 = 9000
            Assert.Equal(9000.00m, po.TotalCost);
            Assert.Equal(9000.00m, po.OrderLines[0].TotalPrice);
            // Also exceeded $5000 threshold -> requires approval
            Assert.True(po.RequiresApproval);
        }

        // =========================================================================
        // 4. BUDGET VALIDATION
        // =========================================================================

        [Fact]
        public async Task ValidateBudget_TotalCostExceedsBudgetLimit_ThrowsException()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "SteelWorks", ContactEmail = "sw@test.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            var emailMock = new Mock<IEmailService>();
            var config = CreateTestConfiguration(5000m);
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var createDto = new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 5000m, // Budget is $5,000
                Lines = new List<OrderLineDto>
                {
                    new OrderLineDto
                    {
                        RawMaterialId = 1,
                        Description = "Too expensive",
                        Quantity = 2000m,
                        UnitPrice = 4.50m // Total is $9,000 > $5,000 budget
                    }
                }
            };

            var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => poService.CreateAsync(createDto));
            Assert.Contains("exceeds budget limit", ex.Message, StringComparison.OrdinalIgnoreCase);
        }

        // =========================================================================
        // 5. APPROVAL THRESHOLD
        // =========================================================================

        [Theory]
        [InlineData(4999.00, false)]
        [InlineData(5000.00, false)]
        [InlineData(5001.00, true)]
        [InlineData(9000.00, true)]
        public async Task CheckApprovalThreshold_CorrectlySetsRequiresApprovalFlag(decimal totalAmount, bool expectedRequiresApproval)
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "ThresholdSupplier", ContactEmail = "ts@test.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            var emailMock = new Mock<IEmailService>();
            var config = CreateTestConfiguration(5000m); // Threshold = $5,000
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var createDto = new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 20000m,
                Lines = new List<OrderLineDto>
                {
                    new OrderLineDto { RawMaterialId = 1, Quantity = 1m, UnitPrice = totalAmount }
                }
            };

            var po = await poService.CreateAsync(createDto);
            Assert.Equal(expectedRequiresApproval, po.RequiresApproval);
        }

        // =========================================================================
        // 6. APPROVAL, STRIPE & SENDGRID HAPPY PATH
        // =========================================================================

        [Fact]
        public async Task Approve_HappyPath_CompletesPaymentAndMarksSent()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "Global Supplier", ContactEmail = "supplier@global.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            stripeMock.Setup(s => s.CreatePaymentIntentAsync(It.IsAny<decimal>(), "usd", It.IsAny<string>()))
                .ReturnsAsync(new StripePaymentResult(true, "pi_test_123", "succeeded", null));

            var emailMock = new Mock<IEmailService>();
            emailMock.Setup(e => e.SendPurchaseOrderEmailAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<byte[]>(), It.IsAny<string>()))
                .Returns(Task.CompletedTask);

            var config = CreateTestConfiguration(5000m);
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var po = await poService.CreateAsync(new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 10000m,
                Lines = new List<OrderLineDto> { new OrderLineDto { RawMaterialId = 1, Quantity = 100, UnitPrice = 10m } }
            });

            // 1. Submit: Draft -> PendingApproval
            var submitted = await poService.SubmitForApprovalAsync(po.Id);
            Assert.Equal("PendingApproval", submitted.Status);

            // 2. Approve: PendingApproval -> Approved -> Payment -> Sent
            var approverId = Guid.NewGuid();
            var approved = await poService.ApproveAsync(po.Id, approverId);

            Assert.Equal("Sent", approved.Status);
            Assert.Equal("pi_test_123", approved.StripePaymentIntentId);
            Assert.Equal("succeeded", approved.StripePaymentStatus);
            stripeMock.Verify(s => s.CreatePaymentIntentAsync(1000m, "usd", It.IsAny<string>()), Times.Once);
            emailMock.Verify(e => e.SendPurchaseOrderEmailAsync(
                "supplier@global.com", "Global Supplier", It.IsAny<string>(), It.IsAny<byte[]>(), It.IsAny<string>()), Times.Once);
        }

        // =========================================================================
        // 7. REJECTION WORKFLOW
        // =========================================================================

        [Fact]
        public async Task Reject_FromPendingApproval_SetsRejectedAndReason()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "Supplier A", ContactEmail = "a@test.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            var emailMock = new Mock<IEmailService>();
            var config = CreateTestConfiguration();
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var po = await poService.CreateAsync(new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 10000m,
                Lines = new List<OrderLineDto> { new OrderLineDto { RawMaterialId = 1, Quantity = 10, UnitPrice = 10m } }
            });

            await poService.SubmitForApprovalAsync(po.Id);

            var approverId = Guid.NewGuid();
            var rejected = await poService.RejectAsync(po.Id, approverId, "Pricing too high compared to market rate.");

            Assert.Equal("Rejected", rejected.Status);
            Assert.Equal("Pricing too high compared to market rate.", rejected.RejectionReason);
        }

        // =========================================================================
        // 8. REVISION WORKFLOW (PendingApproval -> RevisionRequested -> Draft)
        // =========================================================================

        [Fact]
        public async Task RequestRevision_ReturnsToDraft_AllowsEditingAgain()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "Supplier B", ContactEmail = "b@test.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            var emailMock = new Mock<IEmailService>();
            var config = CreateTestConfiguration();
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var po = await poService.CreateAsync(new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 10000m,
                Lines = new List<OrderLineDto> { new OrderLineDto { RawMaterialId = 1, Quantity = 50, UnitPrice = 10m } }
            });

            await poService.SubmitForApprovalAsync(po.Id);

            var approverId = Guid.NewGuid();
            var revised = await poService.RequestRevisionAsync(po.Id, approverId, "Please lower quantity by 20%.");

            // PO reverts to Draft so user can edit
            Assert.Equal("Draft", revised.Status);

            // Now updating PO should succeed because status is Draft again!
            var updated = await poService.UpdateAsync(po.Id, new UpdatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 10000m,
                Lines = new List<OrderLineDto> { new OrderLineDto { RawMaterialId = 1, Quantity = 40, UnitPrice = 10m } }
            });

            Assert.NotNull(updated);
            Assert.Equal(400m, updated.TotalCost);
        }

        // =========================================================================
        // 9. INVALID TRANSITIONS PREVENTED
        // =========================================================================

        [Fact]
        public void StateMachine_InvalidTransitions_ArePrevented()
        {
            // Draft cannot go directly to Approved
            Assert.False(PurchaseOrderStatusTransitions.IsTransitionAllowed(
                PurchaseOrderStatus.Draft, PurchaseOrderStatus.Approved));

            // Draft cannot go directly to Sent
            Assert.False(PurchaseOrderStatusTransitions.IsTransitionAllowed(
                PurchaseOrderStatus.Draft, PurchaseOrderStatus.Sent));

            // Rejected cannot transition anywhere (terminal state)
            Assert.False(PurchaseOrderStatusTransitions.IsTransitionAllowed(
                PurchaseOrderStatus.Rejected, PurchaseOrderStatus.Approved));

            // Sent cannot transition anywhere (terminal state)
            Assert.False(PurchaseOrderStatusTransitions.IsTransitionAllowed(
                PurchaseOrderStatus.Sent, PurchaseOrderStatus.Draft));
        }

        // =========================================================================
        // 10. STRIPE FAILURE SAFELY HANDLED (PO stays in Payment, not Sent)
        // =========================================================================

        [Fact]
        public async Task StripeFailure_POStaysInPayment_NeverMarkedAsSent()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "Supplier C", ContactEmail = "c@test.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            // Simulate Stripe failure (e.g. card declined / sandbox error)
            var stripeMock = new Mock<IStripeService>();
            stripeMock.Setup(s => s.CreatePaymentIntentAsync(It.IsAny<decimal>(), "usd", It.IsAny<string>()))
                .ReturnsAsync(new StripePaymentResult(false, null, "failed", "Insufficient funds"));

            var emailMock = new Mock<IEmailService>();
            var config = CreateTestConfiguration();
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var po = await poService.CreateAsync(new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 10000m,
                Lines = new List<OrderLineDto> { new OrderLineDto { RawMaterialId = 1, Quantity = 10, UnitPrice = 50m } }
            });

            await poService.SubmitForApprovalAsync(po.Id);
            var approverId = Guid.NewGuid();

            var result = await poService.ApproveAsync(po.Id, approverId);

            // Must NOT advance to Sent! Stays in Payment
            Assert.Equal("Payment", result.Status);
            Assert.Equal("failed", result.StripePaymentStatus);

            // Email must NEVER have been called on payment failure
            emailMock.Verify(e => e.SendPurchaseOrderEmailAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<byte[]>(), It.IsAny<string>()), Times.Never);
        }

        // =========================================================================
        // 11. SENDGRID / EMAIL FAILURE SAFELY HANDLED (PO stays in Payment, not Sent)
        // =========================================================================

        [Fact]
        public async Task SendGridFailure_POStaysInPayment_NeverMarkedAsSent()
        {
            using var context = CreateInMemoryDbContext();
            var supplier = new Supplier { Name = "Supplier D", ContactEmail = "d@test.com", IsActive = true };
            context.Suppliers.Add(supplier);
            await context.SaveChangesAsync();

            var stripeMock = new Mock<IStripeService>();
            stripeMock.Setup(s => s.CreatePaymentIntentAsync(It.IsAny<decimal>(), "usd", It.IsAny<string>()))
                .ReturnsAsync(new StripePaymentResult(true, "pi_success_999", "succeeded", null));

            // Simulate email dispatch failure
            var emailMock = new Mock<IEmailService>();
            emailMock.Setup(e => e.SendPurchaseOrderEmailAsync(
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<byte[]>(), It.IsAny<string>()))
                .ThrowsAsync(new InvalidOperationException("SendGrid API connection refused"));

            var config = CreateTestConfiguration();
            var logger = new Mock<ILogger<PurchaseOrderService>>();

            var poService = new PurchaseOrderService(context, stripeMock.Object, emailMock.Object, config, logger.Object);

            var po = await poService.CreateAsync(new CreatePurchaseOrderDto
            {
                SupplierId = supplier.Id,
                BudgetLimit = 10000m,
                Lines = new List<OrderLineDto> { new OrderLineDto { RawMaterialId = 1, Quantity = 10, UnitPrice = 50m } }
            });

            await poService.SubmitForApprovalAsync(po.Id);
            var approverId = Guid.NewGuid();

            var result = await poService.ApproveAsync(po.Id, approverId);

            // Safe failure: PO reached Payment, but since email failed, does NOT become Sent
            Assert.Equal("Payment", result.Status);
        }

        // =========================================================================
        // 12. UNAUTHORIZED APPROVAL & RBAC SECURITY TESTS
        // =========================================================================

        [Fact]
        public async Task Controller_Approve_WithoutValidUserToken_ReturnsUnauthorized()
        {
            var mockPoService = new Mock<IPurchaseOrderService>();
            var controller = new ManufacturingCoordinator.Controllers.PurchaseOrdersController(mockPoService.Object)
            {
                ControllerContext = new Microsoft.AspNetCore.Mvc.ControllerContext
                {
                    HttpContext = new Microsoft.AspNetCore.Http.DefaultHttpContext()
                }
            };

            var actionResult = await controller.Approve(1);
            Assert.IsType<Microsoft.AspNetCore.Mvc.UnauthorizedObjectResult>(actionResult.Result);
        }

        [Theory]
        [InlineData("Create")]
        [InlineData("Update")]
        [InlineData("Submit")]
        [InlineData("Approve")]
        [InlineData("Reject")]
        [InlineData("Revise")]
        public void Controller_RestrictedEndpoints_EnforceSupplyChainManagerRole(string methodName)
        {
            var method = typeof(ManufacturingCoordinator.Controllers.PurchaseOrdersController)
                .GetMethods()
                .FirstOrDefault(m => m.Name == methodName);

            Assert.NotNull(method);
            var authAttr = method.GetCustomAttributes(typeof(Microsoft.AspNetCore.Authorization.AuthorizeAttribute), false)
                .Cast<Microsoft.AspNetCore.Authorization.AuthorizeAttribute>()
                .FirstOrDefault();

            Assert.NotNull(authAttr);
            Assert.Equal("SupplyChainManager", authAttr.Roles);
        }
    }
}
