using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Enums;
using backend.Services;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public class ProcurementService : IProcurementService
    {
        private readonly ApplicationDbContext _context;
        private readonly IAgentIntegrationService _agentService;
        private readonly IPurchaseOrderService _poService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<ProcurementService> _logger;
        private readonly backend.Services.IInventoryService? _inventoryService;

        public ProcurementService(
            ApplicationDbContext context,
            IAgentIntegrationService agentService,
            IPurchaseOrderService poService,
            IConfiguration configuration,
            ILogger<ProcurementService> logger,
            backend.Services.IInventoryService? inventoryService = null)
        {
            _context = context;
            _agentService = agentService;
            _poService = poService;
            _configuration = configuration;
            _logger = logger;
            _inventoryService = inventoryService;
        }

        // ── Deterministic Calculations ────────────────────────────────────────────

        /// <summary>
        /// ASP.NET Core is the authoritative calculator of net deficit.
        /// Formula: netQty = productionRequirement + safetyStock - currentStock - openPoQuantity
        /// Returns 0 if result is negative (surplus stock).
        /// </summary>
        public decimal CalculateNetRequiredQuantity(
            decimal prodRequirement, decimal safetyStock, decimal currentStock, decimal openPoQuantity)
        {
            var net = prodRequirement + safetyStock - currentStock - openPoQuantity;
            return net <= 0 ? 0m : net;
        }

        /// <summary>
        /// Adjusts quantity upward to satisfy MOQ and pack-size constraints.
        /// Returns both final order quantity and total landed cost.
        /// </summary>
        public (decimal finalQuantity, decimal totalCost) CalculateOrderQuantityAndCost(
            decimal netQuantity, decimal moq, decimal packSize, decimal unitPrice)
        {
            if (netQuantity <= 0) return (0m, 0m);

            var adjustedForMoq = Math.Max(netQuantity, moq);

            decimal finalQuantity;
            if (packSize > 0)
            {
                var packs = Math.Ceiling(adjustedForMoq / packSize);
                finalQuantity = packs * packSize;
            }
            else
            {
                finalQuantity = adjustedForMoq;
            }

            var totalCost = Math.Round(finalQuantity * unitPrice, 2);
            return (finalQuantity, totalCost);
        }

        /// <summary>
        /// 6-point deterministic validation engine for a supplier candidate against procurement constraints.
        /// </summary>
        public CandidateValidationResultDto ValidateCandidate(SupplierCandidate candidate, ProcurementRequest request)
        {
            var result = new CandidateValidationResultDto();

            // 1. Quantity & Cost Calculation
            var (finalQty, cost) = CalculateOrderQuantityAndCost(
                request.CalculatedNetQuantity,
                candidate.MinimumOrderQuantity,
                candidate.PackSize,
                candidate.UnitPrice);

            result.RecommendedOrderQuantity = finalQty;
            result.TotalCost = cost;

            // 2. Material Specification Check
            result.SpecificationMatches = string.Equals(candidate.MaterialName?.Trim(), request.MaterialName?.Trim(), StringComparison.OrdinalIgnoreCase) &&
                                         !string.IsNullOrWhiteSpace(request.RequiredSpecification);
            if (!result.SpecificationMatches)
                result.ValidationMessages.Add("Material specification does not match requested specification.");

            // 3. Supplier Approval Check (ARCHITECTURAL REQUIREMENT: UNVERIFIED cannot auto-proceed)
            result.SupplierApproved = string.Equals(candidate.SupplierStatus, "APPROVED", StringComparison.OrdinalIgnoreCase);
            if (!result.SupplierApproved)
                result.ValidationMessages.Add(
                    $"Supplier '{candidate.SupplierName}' is UNVERIFIED. Supply Chain Manager review and onboarding required.");

            // 4. Quality Evidence Check
            result.QualityEvidenceSufficient = !string.IsNullOrWhiteSpace(candidate.QualityEvidence) &&
                                               candidate.QualityEvidence.Length >= 5 &&
                                               !string.Equals(candidate.QualityEvidence, "UNKNOWN", StringComparison.OrdinalIgnoreCase);
            if (!result.QualityEvidenceSufficient)
                result.ValidationMessages.Add("Supplier does not provide sufficient quality certification evidence.");

            // 5. MOQ Respected
            result.MoqRespected = finalQty >= candidate.MinimumOrderQuantity;
            if (!result.MoqRespected)
                result.ValidationMessages.Add(
                    $"Calculated quantity {finalQty} is below minimum order quantity {candidate.MinimumOrderQuantity}.");

            // 6. Lead Time Feasibility
            var estimatedArrival = DateTime.UtcNow.AddDays(candidate.LeadTimeDays);
            result.LeadTimeFeasible = estimatedArrival <= request.RequiredByDate;
            if (!result.LeadTimeFeasible)
                result.ValidationMessages.Add(
                    $"Lead time of {candidate.LeadTimeDays} days exceeds required date ({request.RequiredByDate:yyyy-MM-dd}).");

            // 7. Budget Constraint
            result.BudgetRespected = cost <= request.MaximumBudget;
            if (!result.BudgetRespected)
                result.ValidationMessages.Add(
                    $"Calculated total cost ${cost:F2} exceeds maximum budget of ${request.MaximumBudget:F2}.");

            // Overall: all 6 core checks must pass
            result.IsValid = candidate.UnitPrice > 0 && finalQty > 0 && result.SpecificationMatches &&
                             result.SupplierApproved &&
                             result.QualityEvidenceSufficient &&
                             result.MoqRespected &&
                             result.LeadTimeFeasible &&
                             result.BudgetRespected;

            return result;
        }

        // ── Workflow Operations ───────────────────────────────────────────────────

        public async Task<ProcurementResponseDto> CreateRequestAsync(CreateProcurementRequestDto dto, Guid? createdById = null)
        {
            var rawMaterial = await _context.RawMaterials.FindAsync(dto.RawMaterialId);
            if (rawMaterial == null) throw new KeyNotFoundException($"RawMaterial {dto.RawMaterialId} was not found. Select an existing material.");
            // Verify createdById actually exists in Users table to avoid FK constraint violation
            if (createdById.HasValue)
            {
                var userExists = await _context.Users.AnyAsync(u => u.Id == createdById.Value);
                if (!userExists)
                {
                    createdById = null;
                }
            }

            var inventory = await _context.InventoryItems.SingleOrDefaultAsync(i => i.Sku == rawMaterial.SkuCode)
                ?? throw new InvalidOperationException("Register the SKU balance before requesting procurement.");
            decimal currentStock = inventory.StockLevel;
            var committedLines = await _context.OrderLines.Where(ol => ol.RawMaterialId == rawMaterial.Id &&
                (ol.PurchaseOrder.Status == PurchaseOrderStatus.Approved || ol.PurchaseOrder.Status == PurchaseOrderStatus.Payment ||
                 ol.PurchaseOrder.Status == PurchaseOrderStatus.PaymentPending || ol.PurchaseOrder.Status == PurchaseOrderStatus.Paid ||
                 ol.PurchaseOrder.Status == PurchaseOrderStatus.Sent || ol.PurchaseOrder.Status == PurchaseOrderStatus.InTransit))
                .Select(ol => new { ol.Id, ol.Quantity }).ToListAsync();
            var lineIds = committedLines.Select(l => l.Id).ToList();
            var delivered = await _context.GoodsReceipts.Where(r => lineIds.Contains(r.OrderLineId)).ToListAsync();
            decimal openPoQty = committedLines.Sum(l => Math.Max(0, l.Quantity - delivered.Where(r => r.OrderLineId == l.Id).Sum(r => r.Quantity)));
            // AUTHORITATIVE NET DEFICIT CALCULATION — ASP.NET Core only, NOT AI
            var netQty = CalculateNetRequiredQuantity(
                dto.ProductionRequirement, dto.SafetyStock, currentStock, openPoQty);

            var request = new ProcurementRequest
            {
                RawMaterialId = rawMaterial.Id,
                MaterialName = rawMaterial.Name,
                RequiredSpecification = dto.RequiredSpecification,
                ProductionRequirement = dto.ProductionRequirement,
                CurrentStock = currentStock,
                SafetyStock = dto.SafetyStock,
                ExistingOpenPoQuantity = openPoQty,
                CalculatedNetQuantity = netQty,
                MaximumBudget = dto.MaximumBudget,
                RequiredByDate = dto.RequiredByDate,
                QualityRequirement = dto.QualityRequirement ?? string.Empty,
                PreferredRegion = dto.PreferredRegion,
                Status = ProcurementRequestStatus.Requested,
                FailureReason = null,
                CreatedById = createdById,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.ProcurementRequests.Add(request);
            await _context.SaveChangesAsync();

            return (await GetByIdAsync(request.Id))!;
        }

        public async Task<ProcurementResponseDto> RunAiResearchAsync(int procurementRequestId)
        {
            var request = await _context.ProcurementRequests
                .Include(pr => pr.RawMaterial)
                .Include(pr => pr.Candidates)
                .FirstOrDefaultAsync(pr => pr.Id == procurementRequestId);

            if (request == null)
                throw new KeyNotFoundException($"ProcurementRequest {procurementRequestId} not found.");

            if (request.CalculatedNetQuantity <= 0)
                throw new InvalidOperationException("There is no uncovered material deficit to procure.");
            request.Status = ProcurementRequestStatus.Researching;
            request.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            // Clear previously evaluated candidate records for this request
            if (request.Candidates.Any())
            {
                _context.SupplierCandidates.RemoveRange(request.Candidates);
                request.Candidates.Clear();
            }

            var candidateEntities = new List<SupplierCandidate>();

            // Removed legacy database supplier injection.

            // 2. Invoke Python FastAPI LangGraph workflow via AgentIntegrationService
            //    ASP.NET Core → FastAPI (internal boundary). React/Flutter never call FastAPI directly.
            string? workflowId = null;
            try
            {
                var (wfId, aiCandidates) = await _agentService.ResearchProcurementSuppliersWithWorkflowAsync(
                    materialName: request.MaterialName ?? request.RawMaterial?.Name ?? "Raw Material",
                    specification: request.RequiredSpecification,
                    requiredQuantity: request.ProductionRequirement,
                    preferredRegion: request.PreferredRegion,
                    materialId: request.RawMaterialId.ToString(),
                    currentStock: request.CurrentStock,
                    safetyStock: request.SafetyStock,
                    openPOQuantity: request.ExistingOpenPoQuantity,
                    netDeficit: request.CalculatedNetQuantity,
                    budgetLimit: request.MaximumBudget,
                    unit: "units",
                    qualityRequirement: request.QualityRequirement,
                    requiredByDate: request.RequiredByDate.ToString("yyyy-MM-dd"),
                    procurementRequestId: request.Id);

                workflowId = wfId;

                foreach (var c in aiCandidates)
                {
                    // Map to existing verified supplier if available
                    var existingSupplier = await _context.Suppliers
                        .FirstOrDefaultAsync(s => s.Name.ToLower() == c.SupplierName.ToLower() && s.IsActive);

                    candidateEntities.Add(new SupplierCandidate
                    {
                        ProcurementRequestId = request.Id,
                        SupplierId = existingSupplier?.Id,
                        SupplierName = existingSupplier?.Name ?? c.SupplierName,
                        MaterialName = c.MaterialName,
                        UnitPrice = c.UnitPrice,
                        Currency = string.IsNullOrWhiteSpace(c.Currency) ? "USD" : c.Currency,
                        MinimumOrderQuantity = c.MinimumOrderQuantity,
                        PackSize = c.PackSize > 0 ? c.PackSize : 1m,
                        LeadTimeDays = existingSupplier?.LeadTimeDays > 0 ? existingSupplier.LeadTimeDays : c.LeadTimeDays,
                        QualityEvidence = c.QualityEvidence,
                        Availability = c.Availability,
                        SupplierStatus = existingSupplier != null ? "APPROVED" : "UNVERIFIED",
                        ConfidenceScore = c.ConfidenceScore,
                        SourceUrl = c.SourceUrl,
                        CreatedAt = DateTime.UtcNow
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "AI workflow unreachable for ProcurementRequest {Id}. Proceeding with existing database suppliers only.", procurementRequestId);
            }

            // Persist WorkflowId for audit trail
            if (!string.IsNullOrWhiteSpace(workflowId))
                request.WorkflowId = workflowId;



            // 3. Run deterministic 6-point validation on all candidates
            SupplierCandidate? bestCandidate = null;
            decimal lowestCost = decimal.MaxValue;

            foreach (var candidate in candidateEntities)
            {
                var validation = ValidateCandidate(candidate, request);
                candidate.RecommendedOrderQuantity = validation.RecommendedOrderQuantity;
                candidate.TotalCost = validation.TotalCost;
                candidate.IsValidated = validation.IsValid;
                candidate.ValidationRemarks = string.Join("; ", validation.ValidationMessages);

                _context.SupplierCandidates.Add(candidate);

                if (validation.IsValid && validation.SupplierApproved && validation.TotalCost < lowestCost)
                {
                    lowestCost = validation.TotalCost;
                    bestCandidate = candidate;
                }
            }

            await _context.SaveChangesAsync();

            // 4. Determine recommendation outcome
            if (bestCandidate != null && bestCandidate.SupplierId.HasValue)
            {
                request.RecommendedSupplierId = bestCandidate.SupplierId;
                request.Status = ProcurementRequestStatus.RecommendationReady;
                request.FailureReason = null;
            }
            else
            {
                request.Status = ProcurementRequestStatus.RecommendationReady;
                var unverifiedCount = candidateEntities.Count(c => c.SupplierStatus == "UNVERIFIED");
                request.FailureReason = unverifiedCount > 0
                    ? $"Found {unverifiedCount} market candidate(s) via AI research, but all are UNVERIFIED. Supply Chain Manager verification required before Draft PO can be generated."
                    : "No suitable approved candidate passed specification, lead time, or budget constraints.";
            }

            request.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return (await GetByIdAsync(request.Id))!;
        }

        public async Task<IEnumerable<SupplierCandidateDto>> GetCandidatesAsync(int procurementRequestId)
        {
            var candidates = await _context.SupplierCandidates
                .Where(sc => sc.ProcurementRequestId == procurementRequestId)
                .OrderByDescending(sc => sc.IsValidated)
                .ThenBy(sc => sc.TotalCost)
                .ToListAsync();

            return candidates.Select(MapCandidateToDto);
        }

        public async Task<ProcurementRecommendationDto> GetRecommendationAsync(int procurementRequestId)
        {
            var request = await _context.ProcurementRequests
                .Include(pr => pr.RawMaterial)
                .Include(pr => pr.RecommendedSupplier)
                .Include(pr => pr.GeneratedPurchaseOrder)
                .Include(pr => pr.Candidates)
                .FirstOrDefaultAsync(pr => pr.Id == procurementRequestId);

            if (request == null)
                throw new KeyNotFoundException($"ProcurementRequest {procurementRequestId} not found.");

            // Find best candidate: prefer APPROVED + validated, then lowest cost
            var bestCandidate = request.Candidates
                .Where(c => c.IsValidated && string.Equals(c.SupplierStatus, "APPROVED", StringComparison.OrdinalIgnoreCase))
                .OrderBy(c => c.TotalCost)
                .FirstOrDefault()
                ?? request.Candidates
                    .OrderByDescending(c => c.ConfidenceScore)
                    .FirstOrDefault();

            bool requiresVerification = bestCandidate != null &&
                !string.Equals(bestCandidate.SupplierStatus, "APPROVED", StringComparison.OrdinalIgnoreCase);

            string? rationale = null;
            if (bestCandidate != null)
            {
                rationale = requiresVerification
                    ? $"AI research identified '{bestCandidate.SupplierName}' as the highest-confidence candidate (score: {bestCandidate.ConfidenceScore}%). " +
                      "Supplier is UNVERIFIED — Supply Chain Manager must verify and onboard before Draft PO can be generated."
                    : $"Recommended '{bestCandidate.SupplierName}' based on lowest validated total cost (${bestCandidate.TotalCost:F2}), " +
                      $"quality certification ({bestCandidate.QualityEvidence}), and {bestCandidate.LeadTimeDays}-day lead time within required delivery window.";
            }

            return new ProcurementRecommendationDto
            {
                ProcurementRequestId = procurementRequestId,
                Status = request.Status.ToString(),
                WorkflowId = request.WorkflowId,
                RecommendedCandidate = bestCandidate != null ? MapCandidateToDto(bestCandidate) : null,
                GeneratedPurchaseOrderId = request.GeneratedPurchaseOrderId,
                GeneratedPoNumber = request.GeneratedPurchaseOrder?.PoNumber,
                Rationale = rationale,
                RequiresSupplierVerification = requiresVerification,
                RequiresHumanApproval = request.GeneratedPurchaseOrderId.HasValue &&
                    (request.GeneratedPurchaseOrder?.Status == PurchaseOrderStatus.PendingApproval ||
                     request.GeneratedPurchaseOrder?.Status == PurchaseOrderStatus.Draft),
                FailureReason = request.FailureReason,
                UpdatedAt = request.UpdatedAt
            };
        }

        public async Task<ProcurementStatusTrackingDto?> GetStatusTrackingAsync(int procurementRequestId)
        {
            var request = await _context.ProcurementRequests
                .Include(pr => pr.RawMaterial)
                .Include(pr => pr.RecommendedSupplier)
                .Include(pr => pr.GeneratedPurchaseOrder)
                    .ThenInclude(po => po.Transactions)
                .Include(pr => pr.Candidates)
                .FirstOrDefaultAsync(pr => pr.Id == procurementRequestId);

            if (request == null) return null;

            var po = request.GeneratedPurchaseOrder;

            // Determine Stripe payment status from latest transaction
            string? paymentStatus = null;
            if (po != null)
            {
                var latestTx = po.Transactions?
                    .OrderByDescending(tx => tx.Timestamp)
                    .FirstOrDefault();

                paymentStatus = latestTx != null
                    ? latestTx.PaymentStatus
                    : (po.Status >= PurchaseOrderStatus.Payment ? "Processing" : "Pending");
            }

            // SendGrid notification status from PO status
            string? notificationStatus = null;
            if (po != null)
            {
                notificationStatus = po.Status == PurchaseOrderStatus.Sent ? "Sent" :
                                     po.Status > PurchaseOrderStatus.Payment ? "Delivered" : "NotSent";
            }

            // Best candidate for display
            var bestCandidate = request.Candidates
                .Where(c => c.IsValidated && string.Equals(c.SupplierStatus, "APPROVED", StringComparison.OrdinalIgnoreCase))
                .OrderBy(c => c.TotalCost)
                .FirstOrDefault()
                ?? request.Candidates.OrderByDescending(c => c.ConfidenceScore).FirstOrDefault();

            bool requiresVerification = bestCandidate != null &&
                !string.Equals(bestCandidate.SupplierStatus, "APPROVED", StringComparison.OrdinalIgnoreCase);

            return new ProcurementStatusTrackingDto
            {
                ProcurementId = request.Id,
                MaterialName = request.MaterialName ?? request.RawMaterial?.Name ?? string.Empty,
                RequiredSpecification = request.RequiredSpecification,
                NetDeficit = request.CalculatedNetQuantity,
                ProcurementStatus = request.Status.ToString(),
                WorkflowId = request.WorkflowId,
                PurchaseOrderId = request.GeneratedPurchaseOrderId,
                PurchaseOrderNumber = po?.PoNumber,
                PurchaseOrderStatus = po?.Status.ToString(),
                PaymentStatus = paymentStatus,
                SupplierNotificationStatus = notificationStatus,
                SupplierName = bestCandidate?.SupplierName,
                SupplierStatus = bestCandidate?.SupplierStatus,
                RecommendedQuantity = bestCandidate?.RecommendedOrderQuantity,
                UnitPrice = bestCandidate?.UnitPrice,
                TotalCost = bestCandidate?.TotalCost,
                QualityEvidence = bestCandidate?.QualityEvidence,
                LeadTimeDays = bestCandidate?.LeadTimeDays,
                Availability = bestCandidate?.Availability,
                RequiresSupplierVerification = requiresVerification,
                RequiresHumanApproval = po != null &&
                    (po.Status == PurchaseOrderStatus.Draft || po.Status == PurchaseOrderStatus.PendingApproval),
                LastUpdated = request.UpdatedAt
            };
        }

        public async Task<PurchaseOrderResponseDto> CreateDraftPoFromCandidateAsync(int procurementRequestId, int candidateId, Guid? userId = null)
        {
            var request = await _context.ProcurementRequests
                .Include(pr => pr.RawMaterial)
                .FirstOrDefaultAsync(pr => pr.Id == procurementRequestId);

            if (request == null)
                throw new KeyNotFoundException($"ProcurementRequest {procurementRequestId} not found.");

            var candidate = await _context.SupplierCandidates
                .FirstOrDefaultAsync(c => c.Id == candidateId && c.ProcurementRequestId == procurementRequestId);

            if (candidate == null)
                throw new KeyNotFoundException($"SupplierCandidate {candidateId} not found for this request.");

            // Architectural Gate: UNVERIFIED suppliers cannot generate a Draft PO
            if (!string.Equals(candidate.SupplierStatus, "APPROVED", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException(
                    $"Supplier '{candidate.SupplierName}' is UNVERIFIED. It must be verified and onboarded before a Draft PO can be generated.");

            var validation = ValidateCandidate(candidate, request);
            if (!validation.MoqRespected || !validation.BudgetRespected)
                throw new InvalidOperationException($"Candidate validation failed: {string.Join(", ", validation.ValidationMessages)}");

            var po = await CreateDraftPoInternalAsync(request, candidate, userId);
            request.GeneratedPurchaseOrderId = po.Id;
            request.RecommendedSupplierId = candidate.SupplierId;
            request.Status = ProcurementRequestStatus.DraftPoCreated;
            request.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return po;
        }

        public async Task<ProcurementResponseDto> VerifyAndOnboardSupplierAsync(
            int procurementRequestId,
            int candidateId,
            VerifySupplierCandidateDto dto,
            Guid? userId = null)
        {
            var candidate = await _context.SupplierCandidates
                .FirstOrDefaultAsync(c => c.Id == candidateId && c.ProcurementRequestId == procurementRequestId);

            if (candidate == null)
                throw new KeyNotFoundException($"Candidate {candidateId} not found for ProcurementRequest {procurementRequestId}.");

            var supplier = await _context.Suppliers.FirstOrDefaultAsync(s => s.ContactEmail == dto.ContactEmail);
            if (supplier == null)
            {
                supplier = new Supplier
                {
                    SupplierCode = "SUP-" + Guid.NewGuid().ToString("N")[..6].ToUpperInvariant(),
                    Name = dto.SupplierName,
                    ContactEmail = dto.ContactEmail,
                    ContactPhone = dto.ContactPhone ?? string.Empty,
                    Address = dto.Address ?? string.Empty,
                    PaymentTerms = dto.PaymentTerms,
                    LeadTimeDays = dto.LeadTimeDays > 0 ? dto.LeadTimeDays : candidate.LeadTimeDays,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };
                _context.Suppliers.Add(supplier);
            }
            else
            {
                supplier.IsActive = true;
            }
            await _context.SaveChangesAsync();

            // Link candidate to newly onboarded supplier and approve
            candidate.SupplierId = supplier.Id;
            candidate.SupplierStatus = "APPROVED";
            candidate.ValidationRemarks = $"Verified and onboarded by Supply Chain Manager on {DateTime.UtcNow:yyyy-MM-dd}.";
            candidate.IsValidated = true;

            await _context.SaveChangesAsync();

            return (await GetByIdAsync(procurementRequestId))!;
        }

        // ── Read Queries ──────────────────────────────────────────────────────────

        public async Task<ProcurementResponseDto?> GetByIdAsync(int id)
        {
            var pr = await _context.ProcurementRequests
                .Include(p => p.RawMaterial)
                .Include(p => p.RecommendedSupplier)
                .Include(p => p.GeneratedPurchaseOrder)
                .Include(p => p.Candidates)
                .FirstOrDefaultAsync(p => p.Id == id);

            return pr == null ? null : MapToDto(pr);
        }

        public async Task<IEnumerable<ProcurementResponseDto>> GetAllAsync()
        {
            var requests = await _context.ProcurementRequests
                .Include(p => p.RawMaterial)
                .Include(p => p.RecommendedSupplier)
                .Include(p => p.GeneratedPurchaseOrder)
                .OrderByDescending(p => p.CreatedAt)
                .ToListAsync();

            return requests.Select(pr => new ProcurementResponseDto
            {
                Id = pr.Id,
                RawMaterialId = pr.RawMaterialId,
                RawMaterialName = pr.RawMaterial?.Name ?? string.Empty,
                RawMaterialSku = pr.RawMaterial?.SkuCode ?? string.Empty,
                MaterialName = pr.MaterialName ?? pr.RawMaterial?.Name,
                RequiredSpecification = pr.RequiredSpecification,
                ProductionRequirement = pr.ProductionRequirement,
                CurrentStock = pr.CurrentStock,
                SafetyStock = pr.SafetyStock,
                ExistingOpenPoQuantity = pr.ExistingOpenPoQuantity,
                CalculatedNetQuantity = pr.CalculatedNetQuantity,
                MaximumBudget = pr.MaximumBudget,
                RequiredByDate = pr.RequiredByDate,
                QualityRequirement = pr.QualityRequirement,
                PreferredRegion = pr.PreferredRegion,
                Status = pr.Status.ToString(),
                WorkflowId = pr.WorkflowId,
                RecommendedSupplierId = pr.RecommendedSupplierId,
                RecommendedSupplierName = pr.RecommendedSupplier?.Name,
                GeneratedPurchaseOrderId = pr.GeneratedPurchaseOrderId,
                GeneratedPoNumber = pr.GeneratedPurchaseOrder?.PoNumber,
                FailureReason = pr.FailureReason,
                CreatedAt = pr.CreatedAt,
                UpdatedAt = pr.UpdatedAt,
                Candidates = new List<SupplierCandidateDto>()
            });
        }

        // ── Private Helpers ───────────────────────────────────────────────────────

        private ProcurementResponseDto MapToDto(ProcurementRequest pr) => new()
        {
            Id = pr.Id,
            RawMaterialId = pr.RawMaterialId,
            RawMaterialName = pr.RawMaterial?.Name ?? string.Empty,
            RawMaterialSku = pr.RawMaterial?.SkuCode ?? string.Empty,
            MaterialName = pr.MaterialName ?? pr.RawMaterial?.Name,
            RequiredSpecification = pr.RequiredSpecification,
            ProductionRequirement = pr.ProductionRequirement,
            CurrentStock = pr.CurrentStock,
            SafetyStock = pr.SafetyStock,
            ExistingOpenPoQuantity = pr.ExistingOpenPoQuantity,
            CalculatedNetQuantity = pr.CalculatedNetQuantity,
            MaximumBudget = pr.MaximumBudget,
            RequiredByDate = pr.RequiredByDate,
            QualityRequirement = pr.QualityRequirement,
            PreferredRegion = pr.PreferredRegion,
            Status = pr.Status.ToString(),
            WorkflowId = pr.WorkflowId,
            RecommendedSupplierId = pr.RecommendedSupplierId,
            RecommendedSupplierName = pr.RecommendedSupplier?.Name,
            GeneratedPurchaseOrderId = pr.GeneratedPurchaseOrderId,
            GeneratedPoNumber = pr.GeneratedPurchaseOrder?.PoNumber,
            FailureReason = pr.FailureReason,
            CreatedAt = pr.CreatedAt,
            UpdatedAt = pr.UpdatedAt,
            Candidates = pr.Candidates.Select(MapCandidateToDto).ToList()
        };

        private static SupplierCandidateDto MapCandidateToDto(SupplierCandidate c) => new()
        {
            Id = c.Id,
            SupplierId = c.SupplierId,
            SupplierName = c.SupplierName,
            MaterialName = c.MaterialName,
            UnitPrice = c.UnitPrice,
            Currency = c.Currency,
            MinimumOrderQuantity = c.MinimumOrderQuantity,
            PackSize = c.PackSize,
            LeadTimeDays = c.LeadTimeDays,
            QualityEvidence = c.QualityEvidence,
            Availability = c.Availability,
            SupplierStatus = c.SupplierStatus,
            ConfidenceScore = c.ConfidenceScore,
            SourceUrl = c.SourceUrl,
            IsValidated = c.IsValidated,
            ValidationRemarks = c.ValidationRemarks,
            RecommendedOrderQuantity = c.RecommendedOrderQuantity,
            TotalCost = c.TotalCost,
            CreatedAt = c.CreatedAt
        };

        private async Task<PurchaseOrderResponseDto> CreateDraftPoInternalAsync(
            ProcurementRequest request,
            SupplierCandidate candidate,
            Guid? userId = null)
        {
            // Auto-create a minimal Supplier record from candidate data if not already linked
            if (!candidate.SupplierId.HasValue)
            {
                var targetEmail = candidate.SupplierName.ToLower().Replace(" ", "") + "@supplier.example.com";
                var autoSupplier = await _context.Suppliers.FirstOrDefaultAsync(s => s.ContactEmail == targetEmail);
                if (autoSupplier == null)
                {
                    autoSupplier = new Supplier
                    {
                        SupplierCode = "SUP-" + Guid.NewGuid().ToString("N")[..6].ToUpperInvariant(),
                        Name = candidate.SupplierName,
                        ContactEmail = targetEmail,
                        ContactPhone = string.Empty,
                        Address = candidate.SourceUrl ?? string.Empty,
                        PaymentTerms = "Net 30",
                        LeadTimeDays = candidate.LeadTimeDays > 0 ? candidate.LeadTimeDays : 7,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    };
                    _context.Suppliers.Add(autoSupplier);
                }
                else
                {
                    autoSupplier.IsActive = true;
                }
                await _context.SaveChangesAsync();
                candidate.SupplierId = autoSupplier.Id;
                await _context.SaveChangesAsync();
            }

            var poDto = new CreatePurchaseOrderDto
            {
                SupplierId = candidate.SupplierId.Value,
                Currency = string.IsNullOrWhiteSpace(candidate.Currency) ? "USD" : candidate.Currency,
                BudgetLimit = request.MaximumBudget,
                Notes = $"AI-Assisted Procurement for Request #{request.Id}. " +
                        $"Candidate: {candidate.SupplierName}. Unit Price: ${candidate.UnitPrice}. " +
                        $"Quality: {candidate.QualityEvidence}. Availability: {candidate.Availability}.",
                Lines = new List<OrderLineDto>
                {
                    new OrderLineDto
                    {
                        RawMaterialId = request.RawMaterialId,
                        Description = $"{request.RawMaterial?.Name ?? "Raw Material"} ({request.RequiredSpecification})",
                        Quantity = candidate.RecommendedOrderQuantity,
                        UnitPrice = candidate.UnitPrice
                    }
                }
            };

            var createdPo = await _poService.CreateAsync(poDto, userId ?? request.CreatedById);

            // Note: Alerts are resolved during Purchase Order Approval, not when a Draft PO is created.

            // Record structured outcome telemetry for future learning dataset (Requirement 12)
            try
            {
                var outcome = new ProcurementOutcome
                {
                    Material = request.MaterialName ?? request.RawMaterial?.Name ?? "Raw Material",
                    RequestedQuantity = request.ProductionRequirement > 0 ? request.ProductionRequirement : request.CalculatedNetQuantity,
                    RecommendedQuantity = candidate.RecommendedOrderQuantity,
                    FinalOrderedQuantity = candidate.RecommendedOrderQuantity,
                    RecommendedSupplier = candidate.SupplierName,
                    SelectedSupplier = candidate.SupplierName,
                    EstimatedPrice = candidate.UnitPrice,
                    FinalPrice = candidate.UnitPrice,
                    EstimatedLeadTime = candidate.LeadTimeDays,
                    ActualLeadTime = candidate.LeadTimeDays,
                    QualityEvidence = candidate.QualityEvidence ?? string.Empty,
                    SupplierVerification = candidate.SupplierStatus ?? "VERIFIED",
                    ManagerDecision = "Draft Created",
                    ManagerRevision = null,
                    ProcurementSuccess = true,
                    PaymentSuccess = true,
                    DeliverySuccess = false,
                    QualityOutcome = "Pending Delivery Inspection",
                    CreatedAt = DateTime.UtcNow,
                    PurchaseOrderId = createdPo.Id,
                    ProcurementRequestId = request.Id
                };
                _context.ProcurementOutcomes.Add(outcome);
                await _context.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to record procurement outcome telemetry.");
            }

            return createdPo;
        }

        public async Task<IEnumerable<ProcurementOutcome>> GetOutcomesAsync()
        {
            return await _context.ProcurementOutcomes
                .OrderByDescending(o => o.CreatedAt)
                .ToListAsync();
        }
    }
}
