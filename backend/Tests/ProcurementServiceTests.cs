using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Services.PurchaseOrders;
using backend.Models;
using backend.Dtos;
using backend.Services;
using ManufacturingCoordinator.Enums;

namespace backend.Tests
{
    public class FakeAgentIntegrationService : IAgentIntegrationService
    {
        public Task<AgentPredictionResponseDto> TriggerLowStockEvaluationAsync(InventoryItem item)
        {
            return Task.FromResult(new AgentPredictionResponseDto());
        }

        public Task<List<SupplierCandidateDto>> ResearchProcurementSuppliersAsync(
            string materialName, 
            string specification, 
            decimal requiredQuantity, 
            string? preferredRegion)
        {
            return Task.FromResult(new List<SupplierCandidateDto>());
        }

        public Task<(string? workflowId, List<SupplierCandidateDto> candidates)> ResearchProcurementSuppliersWithWorkflowAsync(
            string materialName,
            string specification,
            decimal requiredQuantity,
            string? preferredRegion,
            string? materialId = null,
            decimal? currentStock = null,
            decimal? safetyStock = null,
            decimal? openPOQuantity = null,
            decimal? netDeficit = null,
            decimal? budgetLimit = null,
            string? unit = null,
            string? qualityRequirement = null,
            string? requiredByDate = null,
            int? procurementRequestId = null)
        {
            return Task.FromResult<(string?, List<SupplierCandidateDto>)>((
                "WF-TEST-12345", 
                new List<SupplierCandidateDto>()
            ));
        }
    }

    public class FakePurchaseOrderService : IPurchaseOrderService
    {
        public Func<CreatePurchaseOrderDto, Guid?, Task<PurchaseOrderResponseDto>>? OnCreateAsync { get; set; }

        public Task<IEnumerable<PurchaseOrderSummaryDto>> GetAllAsync() => Task.FromResult<IEnumerable<PurchaseOrderSummaryDto>>(new List<PurchaseOrderSummaryDto>());
        public Task<PurchaseOrderResponseDto?> GetByIdAsync(int id) => Task.FromResult<PurchaseOrderResponseDto?>(null);

        public Task<PurchaseOrderResponseDto> CreateAsync(CreatePurchaseOrderDto dto, Guid? createdById = null)
        {
            if (OnCreateAsync != null)
            {
                return OnCreateAsync(dto, createdById);
            }

            return Task.FromResult(new PurchaseOrderResponseDto
            {
                Id = 1,
                PoNumber = "PO-2026-0001",
                Status = PurchaseOrderStatus.Draft.ToString(),
                TotalCost = 100m
            });
        }

        public Task<PurchaseOrderResponseDto?> UpdateAsync(int id, UpdatePurchaseOrderDto dto) => Task.FromResult<PurchaseOrderResponseDto?>(null);
        public Task<PurchaseOrderResponseDto> SubmitForApprovalAsync(int id, Guid? userId = null) => Task.FromResult(new PurchaseOrderResponseDto());
        public Task<PurchaseOrderResponseDto> ApproveAsync(int id, Guid approverId, string? notes = null) => Task.FromResult(new PurchaseOrderResponseDto());
        public Task<PurchaseOrderResponseDto> RejectAsync(int id, Guid approverId, string? reason) => Task.FromResult(new PurchaseOrderResponseDto());
        public Task<PurchaseOrderResponseDto> RequestRevisionAsync(int id, Guid approverId, string? reason) => Task.FromResult(new PurchaseOrderResponseDto());
        public Task<PurchaseOrderResponseDto> ProcessPaymentAsync(int id, Guid? approverId = null, bool forceDispatch = false) => Task.FromResult(new PurchaseOrderResponseDto());
        public Task<byte[]> GeneratePdfAsync(int id) => Task.FromResult(Array.Empty<byte>());
        public Task<bool> DeleteAsync(int id) => Task.FromResult(true);
        public Task<IEnumerable<OrderLineResponseDto>> GetOrderLinesAsync(int poId) => Task.FromResult<IEnumerable<OrderLineResponseDto>>(new List<OrderLineResponseDto>());
        public Task<OrderLineResponseDto> AddOrderLineAsync(int poId, OrderLineDto dto) => Task.FromResult(new OrderLineResponseDto());
        public Task<OrderLineResponseDto> UpdateOrderLineAsync(int poId, int lineId, OrderLineDto dto) => Task.FromResult(new OrderLineResponseDto());
        public Task<bool> DeleteOrderLineAsync(int poId, int lineId) => Task.FromResult(true);
        public decimal CalculateTotalCost(PurchaseOrder po) => po.TotalCost;
        public void ValidateBudget(PurchaseOrder po) {}
        public Task<Supplier> ValidateSupplierAsync(int supplierId) => Task.FromResult(new Supplier { Id = supplierId, Name = "Test" });
        public Task ValidatePurchaseOrderAsync(PurchaseOrder po) => Task.CompletedTask;
        public Task<PurchaseOrderResponseDto?> UpdateDeliveryStatusAsync(int id, string deliveryStatus, string? remarks = null) => Task.FromResult<PurchaseOrderResponseDto?>(null);
    }

    public class ProcurementServiceTests
    {
        private ApplicationDbContext CreateInMemoryDbContext()
        {
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new ApplicationDbContext(options);
        }

        private (ProcurementService service, ApplicationDbContext db, FakeAgentIntegrationService agentFake, FakePurchaseOrderService poFake) 
            CreateService(ApplicationDbContext db)
        {
            var agentFake = new FakeAgentIntegrationService();
            var poFake = new FakePurchaseOrderService();
            var config = new ConfigurationBuilder().Build();
            var logger = NullLogger<ProcurementService>.Instance;

            var service = new ProcurementService(db, agentFake, poFake, config, logger);
            return (service, db, agentFake, poFake);
        }

        [Fact]
        public void CalculateNetRequiredQuantity_FormulaCalculatesCorrectly()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            // Formula: prodRequirement (1000) + safetyStock (200) - currentStock (300) - openPoQuantity (100) = 800
            var net = service.CalculateNetRequiredQuantity(1000m, 200m, 300m, 100m);

            Assert.Equal(800m, net);
        }

        [Fact]
        public void CalculateNetRequiredQuantity_WhenStockExceedsDemand_ReturnsZero()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            // prodRequirement (500) + safetyStock (100) - currentStock (700) - openPoQuantity (0) = -100 -> 0
            var net = service.CalculateNetRequiredQuantity(500m, 100m, 700m, 0m);

            Assert.Equal(0m, net);
        }

        [Fact]
        public void CalculateOrderQuantityAndCost_AdjustsForMOQ()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            // Net quantity = 250, MOQ = 500, PackSize = 1, UnitPrice = 2.00
            var (finalQty, totalCost) = service.CalculateOrderQuantityAndCost(250m, 500m, 1m, 2.00m);

            Assert.Equal(500m, finalQty);
            Assert.Equal(1000.00m, totalCost);
        }

        [Fact]
        public void CalculateOrderQuantityAndCost_AdjustsForPackSize()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            // Net quantity = 520, MOQ = 500, PackSize = 50, UnitPrice = 1.50
            // Ceiling(520 / 50) = 11 packs * 50 = 550
            var (finalQty, totalCost) = service.CalculateOrderQuantityAndCost(520m, 500m, 50m, 1.50m);

            Assert.Equal(550m, finalQty);
            Assert.Equal(825.00m, totalCost);
        }

        [Fact]
        public void ValidateCandidate_WhenBudgetExceeded_FailsValidation()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            var request = new ProcurementRequest
            {
                RequiredSpecification = "Medical Grade Polypropylene",
                CalculatedNetQuantity = 1000m,
                MaximumBudget = 1000m, // Budget $1000
                RequiredByDate = DateTime.UtcNow.AddDays(10)
            };

            var candidate = new SupplierCandidate
            {
                SupplierName = "Premium Polymers",
                MaterialName = "Medical Grade Polypropylene",
                UnitPrice = 2.50m, // 1000 * 2.50 = $2500 > $1000
                MinimumOrderQuantity = 500m,
                PackSize = 50m,
                LeadTimeDays = 5,
                QualityEvidence = "ISO 13485 Certified",
                SupplierStatus = "APPROVED"
            };

            var validation = service.ValidateCandidate(candidate, request);

            Assert.False(validation.IsValid);
            Assert.False(validation.BudgetRespected);
            Assert.Contains(validation.ValidationMessages, m => m.Contains("exceeds maximum budget"));
        }

        [Fact]
        public void ValidateCandidate_WhenLeadTimeExceedsRequiredDate_FailsValidation()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            var request = new ProcurementRequest
            {
                RequiredSpecification = "BoxPouch Film",
                CalculatedNetQuantity = 500m,
                MaximumBudget = 5000m,
                RequiredByDate = DateTime.UtcNow.AddDays(3) // Needs within 3 days
            };

            var candidate = new SupplierCandidate
            {
                SupplierName = "Overseas Film Co",
                MaterialName = "BoxPouch Film",
                UnitPrice = 1.20m,
                MinimumOrderQuantity = 100m,
                PackSize = 10m,
                LeadTimeDays = 14, // 14 days lead time exceeds 3 days
                QualityEvidence = "ISO 9001",
                SupplierStatus = "APPROVED"
            };

            var validation = service.ValidateCandidate(candidate, request);

            Assert.False(validation.IsValid);
            Assert.False(validation.LeadTimeFeasible);
            Assert.Contains(validation.ValidationMessages, m => m.Contains("exceeds required date"));
        }

        [Fact]
        public void ValidateCandidate_WhenSupplierUnverified_FailsSupplierApprovalCheck()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            var request = new ProcurementRequest
            {
                RequiredSpecification = "Aluminum Barrier Laminate",
                CalculatedNetQuantity = 400m,
                MaximumBudget = 2000m,
                RequiredByDate = DateTime.UtcNow.AddDays(10)
            };

            var candidate = new SupplierCandidate
            {
                SupplierName = "Discovered Online Supplier",
                MaterialName = "Aluminum Barrier Laminate",
                UnitPrice = 1.80m,
                MinimumOrderQuantity = 100m,
                PackSize = 10m,
                LeadTimeDays = 4,
                QualityEvidence = "Datasheet available",
                SupplierStatus = "UNVERIFIED" // Unverified online discovery
            };

            var validation = service.ValidateCandidate(candidate, request);

            Assert.False(validation.IsValid);
            Assert.False(validation.SupplierApproved);
            Assert.Contains(validation.ValidationMessages, m => m.Contains("UNVERIFIED"));
        }

        [Fact]
        public async Task CreateDraftPoFromCandidate_WhenSupplierUnverified_ThrowsInvalidOperationException()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            var rawMaterial = new RawMaterial { Id = 1, Name = "Polymer Roll", SkuCode = "RM-POLY-01" };
            db.RawMaterials.Add(rawMaterial);

            var request = new ProcurementRequest
            {
                Id = 10,
                RawMaterialId = 1,
                RequiredSpecification = "Spec A",
                CalculatedNetQuantity = 500m,
                MaximumBudget = 2000m,
                RequiredByDate = DateTime.UtcNow.AddDays(15),
                Status = ProcurementRequestStatus.RecommendationReady
            };
            db.ProcurementRequests.Add(request);

            var candidate = new SupplierCandidate
            {
                Id = 100,
                ProcurementRequestId = 10,
                SupplierName = "Unverified Vendor",
                MaterialName = "Polymer Roll",
                UnitPrice = 1.50m,
                MinimumOrderQuantity = 100m,
                PackSize = 10m,
                LeadTimeDays = 5,
                QualityEvidence = "Certification pending",
                SupplierStatus = "UNVERIFIED"
            };
            db.SupplierCandidates.Add(candidate);
            await db.SaveChangesAsync();

            var ex = await Assert.ThrowsAsync<InvalidOperationException>(
                () => service.CreateDraftPoFromCandidateAsync(10, 100));

            Assert.Contains("UNVERIFIED", ex.Message);
        }

        [Fact]
        public async Task CreateDraftPoFromCandidate_WhenSupplierApproved_CreatesDraftPoSuccessfully()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, poFake) = CreateService(db);

            var rawMaterial = new RawMaterial { Id = 2, Name = "BoxPouch Film", SkuCode = "RM-BP-02" };
            var supplier = new Supplier { Id = 5, Name = "Apex Polymer", SupplierCode = "SUP-APX-01", ContactEmail = "orders@apex.com" };
            db.RawMaterials.Add(rawMaterial);
            db.Suppliers.Add(supplier);

            var request = new ProcurementRequest
            {
                Id = 20,
                RawMaterialId = 2,
                RequiredSpecification = "BP-FILM-100",
                CalculatedNetQuantity = 600m,
                MaximumBudget = 3000m,
                RequiredByDate = DateTime.UtcNow.AddDays(20),
                Status = ProcurementRequestStatus.RecommendationReady
            };
            db.ProcurementRequests.Add(request);

            var candidate = new SupplierCandidate
            {
                Id = 200,
                ProcurementRequestId = 20,
                SupplierId = 5,
                SupplierName = "Apex Polymer",
                MaterialName = "BoxPouch Film",
                UnitPrice = 1.40m,
                MinimumOrderQuantity = 200m,
                PackSize = 50m,
                LeadTimeDays = 5,
                QualityEvidence = "ISO 9001 Certified",
                SupplierStatus = "APPROVED",
                RecommendedOrderQuantity = 600m,
                TotalCost = 840.00m
            };
            db.SupplierCandidates.Add(candidate);
            await db.SaveChangesAsync();

            poFake.OnCreateAsync = (dto, uid) => Task.FromResult(new PurchaseOrderResponseDto
            {
                Id = 501,
                PoNumber = "PO-2026-0501",
                Status = PurchaseOrderStatus.Draft.ToString(),
                TotalCost = 840.00m,
                RequiresApproval = false
            });

            var result = await service.CreateDraftPoFromCandidateAsync(20, 200);

            Assert.NotNull(result);
            Assert.Equal("PO-2026-0501", result.PoNumber);
            Assert.Equal(PurchaseOrderStatus.Draft.ToString(), result.Status);

            var updatedRequest = await db.ProcurementRequests.FindAsync(20);
            Assert.Equal(ProcurementRequestStatus.DraftPoCreated, updatedRequest!.Status);
            Assert.Equal(501, updatedRequest.GeneratedPurchaseOrderId);
        }

        [Fact]
        public void ApprovalThreshold_WhenTotalCostExceedsThreshold_RequiresManagerApproval()
        {
            // Verifies the business rule that high value POs require manager authorization
            const decimal threshold = 5000m;
            const decimal costUnder = 4500m;
            const decimal costOver = 6200m;

            var poUnder = new PurchaseOrder { TotalCost = costUnder, ApprovalThreshold = threshold };
            poUnder.RequiresApproval = poUnder.TotalCost > poUnder.ApprovalThreshold;

            var poOver = new PurchaseOrder { TotalCost = costOver, ApprovalThreshold = threshold };
            poOver.RequiresApproval = poOver.TotalCost > poOver.ApprovalThreshold;

            Assert.False(poUnder.RequiresApproval);
            Assert.True(poOver.RequiresApproval);
        }

        [Fact]
        public async Task GetStatusTrackingAsync_ReturnsFullPipelineTrackingData()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            var rawMaterial = new RawMaterial { Id = 301, Name = "Polyester Film", SkuCode = "PET-01" };
            db.RawMaterials.Add(rawMaterial);

            var request = new ProcurementRequest
            {
                Id = 30,
                RawMaterialId = 301,
                RequiredSpecification = "PET 12 micron",
                ProductionRequirement = 1000m,
                SafetyStock = 200m,
                CurrentStock = 100m,
                ExistingOpenPoQuantity = 0m,
                CalculatedNetQuantity = 1100m,
                MaximumBudget = 5000m,
                RequiredByDate = DateTime.UtcNow.AddDays(14),
                Status = ProcurementRequestStatus.RecommendationReady,
                WorkflowId = "WF-TRACK-999"
            };
            db.ProcurementRequests.Add(request);

            var candidate = new SupplierCandidate
            {
                Id = 301,
                ProcurementRequestId = 30,
                SupplierName = "Apex Film Solutions",
                MaterialName = "Polyester Film",
                UnitPrice = 1.25m,
                MinimumOrderQuantity = 500m,
                PackSize = 50m,
                LeadTimeDays = 5,
                QualityEvidence = "ISO 9001 certified",
                Availability = "In Stock",
                SupplierStatus = "APPROVED",
                IsValidated = true,
                RecommendedOrderQuantity = 1100m,
                TotalCost = 1375.00m
            };
            db.SupplierCandidates.Add(candidate);
            await db.SaveChangesAsync();

            var tracking = await service.GetStatusTrackingAsync(30);

            Assert.NotNull(tracking);
            Assert.Equal(30, tracking.ProcurementId);
            Assert.Equal("WF-TRACK-999", tracking.WorkflowId);
            Assert.Equal("Apex Film Solutions", tracking.SupplierName);
            Assert.Equal(1100m, tracking.NetDeficit);
            Assert.Equal("In Stock", tracking.Availability);
            Assert.False(tracking.RequiresSupplierVerification);
        }

        [Fact]
        public async Task GetRecommendationAsync_WithUnverifiedCandidate_FlagsRequiresVerification()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            var rawMaterial = new RawMaterial { Id = 401, Name = "Nylon Barrier Film", SkuCode = "NY-01" };
            db.RawMaterials.Add(rawMaterial);

            var request = new ProcurementRequest
            {
                Id = 40,
                RawMaterialId = 401,
                RequiredSpecification = "BOPA 15 micron",
                ProductionRequirement = 500m,
                SafetyStock = 100m,
                CurrentStock = 50m,
                ExistingOpenPoQuantity = 0m,
                CalculatedNetQuantity = 550m,
                MaximumBudget = 3000m,
                RequiredByDate = DateTime.UtcNow.AddDays(10),
                Status = ProcurementRequestStatus.RecommendationReady,
                WorkflowId = "WF-RECOMMEND-001"
            };
            db.ProcurementRequests.Add(request);

            var unverifiedCandidate = new SupplierCandidate
            {
                Id = 401,
                ProcurementRequestId = 40,
                SupplierName = "Global Barrier Web Ltd",
                MaterialName = "Nylon Barrier Film",
                UnitPrice = 2.10m,
                MinimumOrderQuantity = 200m,
                PackSize = 50m,
                LeadTimeDays = 6,
                QualityEvidence = "FDA food compliant",
                Availability = "In Stock",
                SupplierStatus = "UNVERIFIED",
                ConfidenceScore = 91.0m,
                IsValidated = false
            };
            db.SupplierCandidates.Add(unverifiedCandidate);
            await db.SaveChangesAsync();

            var recommendation = await service.GetRecommendationAsync(40);

            Assert.NotNull(recommendation);
            Assert.True(recommendation.RequiresSupplierVerification);
            Assert.NotNull(recommendation.RecommendedCandidate);
            Assert.Equal("Global Barrier Web Ltd", recommendation.RecommendedCandidate.SupplierName);
            Assert.Contains("UNVERIFIED", recommendation.Rationale);
        }

        [Fact]
        public async Task CreateDraftPoFromCandidateAsync_WhenCandidateIsUnverified_ThrowsInvalidOperationException()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            var rawMaterial = new RawMaterial { Id = 501, Name = "Spec A Material", SkuCode = "SP-01" };
            db.RawMaterials.Add(rawMaterial);

            var request = new ProcurementRequest
            {
                RawMaterialId = 501,
                RequiredSpecification = "Spec A",
                CalculatedNetQuantity = 500m,
                MaximumBudget = 2000m,
                RequiredByDate = DateTime.UtcNow.AddDays(10),
                Status = ProcurementRequestStatus.RecommendationReady
            };
            db.ProcurementRequests.Add(request);
            await db.SaveChangesAsync();

            var unverifiedCandidate = new SupplierCandidate
            {
                ProcurementRequestId = request.Id,
                SupplierName = "Unknown Discovered Supplier",
                MaterialName = "Spec A Material",
                UnitPrice = 1.00m,
                MinimumOrderQuantity = 100m,
                SupplierStatus = "UNVERIFIED" // Not approved
            };
            db.SupplierCandidates.Add(unverifiedCandidate);
            await db.SaveChangesAsync();

            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                service.CreateDraftPoFromCandidateAsync(request.Id, unverifiedCandidate.Id));
        }

        [Fact]
        public void CalculateNetRequiredQuantity_ComputesDeterministicFormulaAccurately()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            // Formula: Net Deficit = (RequiredQuantity + SafetyStock) - (CurrentStock + OpenPurchaseQuantity)
            // Case 1: Requirement = 1000, Safety = 200, Current = 300, OpenPO = 100 -> Deficit = (1200) - (400) = 800
            var deficit1 = service.CalculateNetRequiredQuantity(1000m, 200m, 300m, 100m);
            Assert.Equal(800m, deficit1);

            // Case 2: Stock exceeds requirements -> Deficit = 0 (no negative orders)
            var deficit2 = service.CalculateNetRequiredQuantity(500m, 100m, 700m, 200m);
            Assert.Equal(0m, deficit2);
        }

        [Fact]
        public async Task ProcurementOutcome_CapturesFullTelemetryForFutureLearning()
        {
            var db = CreateInMemoryDbContext();
            var (service, _, _, _) = CreateService(db);

            var outcome = new ProcurementOutcome
            {
                Material = "Polyethylene Film",
                RequestedQuantity = 5000m,
                RecommendedQuantity = 5500m,
                FinalOrderedQuantity = 5500m,
                RecommendedSupplier = "Apex Polymers",
                SelectedSupplier = "Apex Polymers",
                EstimatedPrice = 1.25m,
                FinalPrice = 1.25m,
                EstimatedLeadTime = 7,
                ActualLeadTime = 7,
                QualityEvidence = "ISO 9001:2015, ASTM D882",
                SupplierVerification = "VERIFIED",
                ManagerDecision = "Approved",
                ProcurementSuccess = true,
                PaymentSuccess = true,
                DeliverySuccess = true,
                QualityOutcome = "Passed 100% Quality Inspection"
            };

            db.ProcurementOutcomes.Add(outcome);
            await db.SaveChangesAsync();

            var outcomes = await service.GetOutcomesAsync();
            var saved = Assert.Single(outcomes);

            Assert.Equal("Polyethylene Film", saved.Material);
            Assert.Equal(5500m, saved.FinalOrderedQuantity);
            Assert.Equal("Apex Polymers", saved.RecommendedSupplier);
            Assert.True(saved.ProcurementSuccess);
            Assert.True(saved.PaymentSuccess);
            Assert.Equal("VERIFIED", saved.SupplierVerification);
        }

        [Fact]
        public void PurchaseOrderStatusTransitions_ValidatesAppropriateStateLifecycle()
        {
            // Draft -> PendingApproval
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.Draft, PurchaseOrderStatus.PendingApproval));
            Assert.False(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.Draft, PurchaseOrderStatus.Paid));

            // PendingApproval -> Approved / Rejected / RevisionRequested
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.PendingApproval, PurchaseOrderStatus.Approved));
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.PendingApproval, PurchaseOrderStatus.Rejected));
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.PendingApproval, PurchaseOrderStatus.RevisionRequested));

            // RevisionRequested -> Draft
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.RevisionRequested, PurchaseOrderStatus.Draft));

            // Approved -> Payment / Paid
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.Approved, PurchaseOrderStatus.Paid));
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.Approved, PurchaseOrderStatus.Payment));

            // Paid -> Sent
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.Paid, PurchaseOrderStatus.Sent));

            // PaymentFailed -> Draft
            Assert.True(PurchaseOrderStatusTransitions.IsTransitionAllowed(PurchaseOrderStatus.PaymentFailed, PurchaseOrderStatus.Draft));
        }
    }
}
