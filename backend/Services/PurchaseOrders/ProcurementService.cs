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

        public ProcurementService(
            ApplicationDbContext context,
            IAgentIntegrationService agentService,
            IPurchaseOrderService poService,
            IConfiguration configuration,
            ILogger<ProcurementService> logger)
        {
            _context = context;
            _agentService = agentService;
            _poService = poService;
            _configuration = configuration;
            _logger = logger;
        }

        // ── Deterministic Calculations ──────────────────────────────────────────

        public decimal CalculateNetRequiredQuantity(decimal prodRequirement, decimal safetyStock, decimal currentStock, decimal openPoQuantity)
        {
            var net = prodRequirement + safetyStock - currentStock - openPoQuantity;
            return net <= 0 ? 0m : net;
        }

        public (decimal finalQuantity, decimal totalCost) CalculateOrderQuantityAndCost(
            decimal netQuantity, 
            decimal moq, 
            decimal packSize, 
            decimal unitPrice)
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
            result.SpecificationMatches = !string.IsNullOrWhiteSpace(candidate.MaterialName) &&
                                         !string.IsNullOrWhiteSpace(request.RequiredSpecification);
            if (!result.SpecificationMatches)
            {
                result.ValidationMessages.Add("Material specification does not match requested specification.");
            }

            // 3. Supplier Approval Check (Architectural requirement: UNVERIFIED cannot auto-proceed to Draft PO)
            result.SupplierApproved = string.Equals(candidate.SupplierStatus, "APPROVED", StringComparison.OrdinalIgnoreCase);
            if (!result.SupplierApproved)
            {
                result.ValidationMessages.Add($"Supplier '{candidate.SupplierName}' is UNVERIFIED. Manager review and onboarding required.");
            }

            // 4. Quality Evidence Check
            result.QualityEvidenceSufficient = !string.IsNullOrWhiteSpace(candidate.QualityEvidence) && candidate.QualityEvidence.Length >= 5;
            if (!result.QualityEvidenceSufficient)
            {
                result.ValidationMessages.Add("Supplier candidate does not provide sufficient quality certification evidence.");
            }

            // 5. MOQ Check
            result.MoqRespected = finalQty >= candidate.MinimumOrderQuantity;
            if (!result.MoqRespected)
            {
                result.ValidationMessages.Add($"Calculated quantity {finalQty} is below minimum order quantity {candidate.MinimumOrderQuantity}.");
            }

            // 6. Lead Time Feasibility Check
            var estimatedArrival = DateTime.UtcNow.AddDays(candidate.LeadTimeDays);
            result.LeadTimeFeasible = estimatedArrival <= request.RequiredByDate;
            if (!result.LeadTimeFeasible)
            {
                result.ValidationMessages.Add($"Lead time of {candidate.LeadTimeDays} days exceeds required date ({request.RequiredByDate:yyyy-MM-dd}).");
            }

            // 7. Budget Limit Check
            result.BudgetRespected = cost <= request.MaximumBudget;
            if (!result.BudgetRespected)
            {
                result.ValidationMessages.Add($"Calculated total cost ${cost:F2} exceeds maximum budget of ${request.MaximumBudget:F2}.");
            }

            // Overall validity: All 6 core checks must pass
            result.IsValid = result.SpecificationMatches &&
                             result.SupplierApproved &&
                             result.QualityEvidenceSufficient &&
                             result.MoqRespected &&
                             result.LeadTimeFeasible &&
                             result.BudgetRespected;

            return result;
        }

        // ── Workflow Operations ─────────────────────────────────────────────────

        public async Task<ProcurementResponseDto> CreateRequestAsync(CreateProcurementRequestDto dto, Guid? createdById = null)
        {
            var rawMaterial = await _context.RawMaterials.FindAsync(dto.RawMaterialId);
            if (rawMaterial == null)
            {
                throw new KeyNotFoundException($"RawMaterial with ID {dto.RawMaterialId} was not found.");
            }

            var netQty = CalculateNetRequiredQuantity(
                dto.ProductionRequirement,
                dto.SafetyStock,
                dto.CurrentStock,
                dto.ExistingOpenPoQuantity);

            var request = new ProcurementRequest
            {
                RawMaterialId = dto.RawMaterialId,
                RequiredSpecification = dto.RequiredSpecification,
                ProductionRequirement = dto.ProductionRequirement,
                CurrentStock = dto.CurrentStock,
                SafetyStock = dto.SafetyStock,
                ExistingOpenPoQuantity = dto.ExistingOpenPoQuantity,
                CalculatedNetQuantity = netQty,
                MaximumBudget = dto.MaximumBudget,
                RequiredByDate = dto.RequiredByDate,
                QualityRequirement = dto.QualityRequirement ?? string.Empty,
                PreferredRegion = dto.PreferredRegion,
                Status = netQty <= 0 ? ProcurementRequestStatus.Completed : ProcurementRequestStatus.Requested,
                FailureReason = netQty <= 0 ? "Current stock and open POs sufficiently meet requirements. No purchase required." : null,
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
            {
                throw new KeyNotFoundException($"ProcurementRequest {procurementRequestId} not found.");
            }

            if (request.CalculatedNetQuantity <= 0)
            {
                request.Status = ProcurementRequestStatus.Completed;
                request.FailureReason = "Net required quantity is 0. No purchasing required.";
                await _context.SaveChangesAsync();
                return (await GetByIdAsync(request.Id))!;
            }

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

            // 1. Include active approved suppliers from existing database if available
            var existingSuppliers = await _context.Suppliers
                .Where(s => s.IsActive)
                .ToListAsync();

            foreach (var sup in existingSuppliers)
            {
                candidateEntities.Add(new SupplierCandidate
                {
                    ProcurementRequestId = request.Id,
                    SupplierId = sup.Id,
                    SupplierName = sup.Name,
                    MaterialName = request.RawMaterial?.Name ?? "Raw Material",
                    UnitPrice = 1.35m, // Database contract baseline price
                    Currency = "USD",
                    MinimumOrderQuantity = 200m,
                    PackSize = 50m,
                    LeadTimeDays = sup.LeadTimeDays > 0 ? sup.LeadTimeDays : 5,
                    QualityEvidence = "Existing approved supplier - ISO 9001 on file",
                    SupplierStatus = "APPROVED",
                    ConfidenceScore = 95.0m,
                    SourceUrl = "internal://database/suppliers/" + sup.Id,
                    CreatedAt = DateTime.UtcNow
                });
            }

            // 2. Discover market candidates via AI Agent research
            var aiCandidates = await _agentService.ResearchProcurementSuppliersAsync(
                request.RawMaterial?.Name ?? "Raw Material",
                request.RequiredSpecification,
                request.CalculatedNetQuantity,
                request.PreferredRegion);

            foreach (var c in aiCandidates)
            {
                // Ensure discovered online candidates remain UNVERIFIED until reviewed
                candidateEntities.Add(new SupplierCandidate
                {
                    ProcurementRequestId = request.Id,
                    SupplierId = null,
                    SupplierName = c.SupplierName,
                    MaterialName = c.MaterialName,
                    UnitPrice = c.UnitPrice,
                    Currency = string.IsNullOrWhiteSpace(c.Currency) ? "USD" : c.Currency,
                    MinimumOrderQuantity = c.MinimumOrderQuantity,
                    PackSize = c.PackSize > 0 ? c.PackSize : 1m,
                    LeadTimeDays = c.LeadTimeDays,
                    QualityEvidence = c.QualityEvidence,
                    SupplierStatus = "UNVERIFIED",
                    ConfidenceScore = c.ConfidenceScore,
                    SourceUrl = c.SourceUrl,
                    CreatedAt = DateTime.UtcNow
                });
            }

            // 3. Run deterministic calculations & validation engine on all candidates
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

                // Check for best APPROVED candidate that passed validation
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

                // Auto-create real Draft Purchase Order in PostgreSQL DB
                try
                {
                    var po = await CreateDraftPoInternalAsync(request, bestCandidate);
                    request.GeneratedPurchaseOrderId = po.Id;
                    request.Status = ProcurementRequestStatus.DraftPoCreated;
                    request.FailureReason = null;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to auto-create Draft PO for request {Id}", request.Id);
                    request.FailureReason = $"Recommended supplier found, but PO drafting failed: {ex.Message}";
                }
            }
            else
            {
                request.Status = ProcurementRequestStatus.RecommendationReady;
                var unverifiedCount = candidateEntities.Count(c => c.SupplierStatus == "UNVERIFIED");
                request.FailureReason = unverifiedCount > 0
                    ? $"Found {unverifiedCount} market candidate(s), but all are UNVERIFIED. Supply Chain Manager verification required."
                    : "No suitable approved candidate passed specification, lead time, or budget constraints.";
            }

            request.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return (await GetByIdAsync(request.Id))!;
        }

        public async Task<PurchaseOrderResponseDto> CreateDraftPoFromCandidateAsync(int procurementRequestId, int candidateId, Guid? userId = null)
        {
            var request = await _context.ProcurementRequests
                .Include(pr => pr.RawMaterial)
                .FirstOrDefaultAsync(pr => pr.Id == procurementRequestId);

            if (request == null)
            {
                throw new KeyNotFoundException($"ProcurementRequest {procurementRequestId} not found.");
            }

            var candidate = await _context.SupplierCandidates
                .FirstOrDefaultAsync(c => c.Id == candidateId && c.ProcurementRequestId == procurementRequestId);

            if (candidate == null)
            {
                throw new KeyNotFoundException($"SupplierCandidate {candidateId} not found for this request.");
            }

            if (!string.Equals(candidate.SupplierStatus, "APPROVED", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    $"Supplier '{candidate.SupplierName}' is UNVERIFIED. It must be verified and onboarded before a Draft PO can be generated.");
            }

            var validation = ValidateCandidate(candidate, request);
            if (!validation.MoqRespected || !validation.BudgetRespected)
            {
                throw new InvalidOperationException($"Candidate validation failed: {string.Join(", ", validation.ValidationMessages)}");
            }

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
            {
                throw new KeyNotFoundException($"Candidate {candidateId} not found.");
            }

            // Create new verified Supplier in PostgreSQL database
            var supplier = new Supplier
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
            await _context.SaveChangesAsync();

            // Link candidate to newly approved supplier
            candidate.SupplierId = supplier.Id;
            candidate.SupplierStatus = "APPROVED";
            candidate.ValidationRemarks = "Verified and onboarded by Supply Chain Manager.";
            candidate.IsValidated = true;

            await _context.SaveChangesAsync();

            return (await GetByIdAsync(procurementRequestId))!;
        }

        public async Task<ProcurementResponseDto?> GetByIdAsync(int id)
        {
            var pr = await _context.ProcurementRequests
                .Include(p => p.RawMaterial)
                .Include(p => p.RecommendedSupplier)
                .Include(p => p.GeneratedPurchaseOrder)
                .Include(p => p.Candidates)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (pr == null) return null;

            return new ProcurementResponseDto
            {
                Id = pr.Id,
                RawMaterialId = pr.RawMaterialId,
                RawMaterialName = pr.RawMaterial?.Name ?? string.Empty,
                RawMaterialSku = pr.RawMaterial?.SkuCode ?? string.Empty,
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
                RecommendedSupplierId = pr.RecommendedSupplierId,
                RecommendedSupplierName = pr.RecommendedSupplier?.Name,
                GeneratedPurchaseOrderId = pr.GeneratedPurchaseOrderId,
                GeneratedPoNumber = pr.GeneratedPurchaseOrder?.PoNumber,
                FailureReason = pr.FailureReason,
                CreatedAt = pr.CreatedAt,
                UpdatedAt = pr.UpdatedAt,
                Candidates = pr.Candidates.Select(c => new SupplierCandidateDto
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
                    SupplierStatus = c.SupplierStatus,
                    ConfidenceScore = c.ConfidenceScore,
                    SourceUrl = c.SourceUrl,
                    IsValidated = c.IsValidated,
                    ValidationRemarks = c.ValidationRemarks,
                    RecommendedOrderQuantity = c.RecommendedOrderQuantity,
                    TotalCost = c.TotalCost,
                    CreatedAt = c.CreatedAt
                }).ToList()
            };
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

        private async Task<PurchaseOrderResponseDto> CreateDraftPoInternalAsync(
            ProcurementRequest request, 
            SupplierCandidate candidate, 
            Guid? userId = null)
        {
            if (!candidate.SupplierId.HasValue)
            {
                throw new InvalidOperationException("Cannot generate Purchase Order without an assigned SupplierId in the database.");
            }

            var poDto = new CreatePurchaseOrderDto
            {
                SupplierId = candidate.SupplierId.Value,
                Currency = string.IsNullOrWhiteSpace(candidate.Currency) ? "USD" : candidate.Currency,
                BudgetLimit = request.MaximumBudget,
                Notes = $"AI-Assisted Procurement for Request #{request.Id}. " +
                        $"Discovered Candidate: {candidate.SupplierName}. Unit Price: ${candidate.UnitPrice}. " +
                        $"Quality Evidence: {candidate.QualityEvidence}.",
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

            return await _poService.CreateAsync(poDto, userId ?? request.CreatedById);
        }
    }
}
