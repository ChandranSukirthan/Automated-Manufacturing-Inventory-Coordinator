using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using iText.Kernel.Pdf;
using iText.Kernel.Colors;
using iText.Layout;
using iText.Layout.Borders;
using iText.Layout.Element;
using iText.Layout.Properties;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.Administration;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Api.Interfaces;
using backend.Data;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public class PurchaseOrderService : IPurchaseOrderService
    {
        private readonly ApplicationDbContext _context;
        private readonly ManufacturingContext? _mfgContext;
        private readonly IStripeService _stripeService;
        private readonly IEmailService _emailService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<PurchaseOrderService> _logger;

        private const string DefaultCurrency = "usd";

        public PurchaseOrderService(
            ApplicationDbContext context,
            IStripeService stripeService,
            IEmailService emailService,
            IConfiguration configuration,
            ILogger<PurchaseOrderService> logger,
            ManufacturingContext? mfgContext = null)
        {
            _context = context;
            _stripeService = stripeService;
            _emailService = emailService;
            _configuration = configuration;
            _logger = logger;
            _mfgContext = mfgContext;
        }

        // ── Query ─────────────────────────────────────────────────────────────────

        public async Task<IEnumerable<PurchaseOrderSummaryDto>> GetAllAsync()
        {
            return await _context.PurchaseOrders
                .Include(po => po.Supplier)
                .OrderByDescending(po => po.CreatedAt)
                .Select(po => new PurchaseOrderSummaryDto
                {
                    Id = po.Id,
                    PoNumber = po.PoNumber,
                    SupplierName = po.Supplier.Name,
                    Status = po.Status.ToString(),
                    Currency = po.Currency,
                    TotalCost = po.TotalCost,
                    RequiresApproval = po.RequiresApproval,
                    CreatedAt = po.CreatedAt,
                    UpdatedAt = po.UpdatedAt
                })
                .ToListAsync();
        }

        public async Task<PurchaseOrderResponseDto?> GetByIdAsync(int id)
        {
            var po = await _context.PurchaseOrders
                .Include(p => p.Supplier)
                .Include(p => p.CreatedBy)
                .Include(p => p.ApprovedBy)
                .Include(p => p.OrderLines)
                    .ThenInclude(ol => ol.RawMaterial)
                .Include(p => p.Approvals)
                .Include(p => p.Transactions)
                .FirstOrDefaultAsync(p => p.Id == id);

            return po is null ? null : MapToDto(po);
        }

        // ── Create ────────────────────────────────────────────────────────────────

        public async Task<PurchaseOrderResponseDto> CreateAsync(CreatePurchaseOrderDto dto, Guid? createdById = null)
        {
            // Business Operation 3: validateSupplier()
            var supplier = await ValidateSupplierAsync(dto.SupplierId);

            var approvalThreshold = _configuration.GetValue<decimal>(
                "PurchaseOrderSettings:ApprovalThresholdAmount", 5000m);

            var po = new PurchaseOrder
            {
                PoNumber = await GeneratePoNumberAsync(),
                SupplierId = dto.SupplierId,
                Currency = string.IsNullOrWhiteSpace(dto.Currency) ? "USD" : dto.Currency.Trim().ToUpperInvariant(),
                BudgetLimit = dto.BudgetLimit,
                Notes = dto.Notes,
                ProcurementRequestId = dto.ProcurementRequestId,
                TrackingStatus = "Draft",
                Status = PurchaseOrderStatus.Draft,
                ApprovalThreshold = approvalThreshold,
                CreatedById = createdById,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            // Build order lines
            foreach (var lineDto in dto.Lines)
            {
                var line = new OrderLine
                {
                    RawMaterialId = lineDto.RawMaterialId > 0 ? lineDto.RawMaterialId : lineDto.MaterialId,
                    Description = lineDto.Description,
                    Quantity = lineDto.Quantity,
                    UnitPrice = lineDto.UnitPrice,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };
                line.TotalPrice = CalculateLineCost(line);
                po.OrderLines.Add(line);
            }

            // Business Operation 1: calculateTotalCost()
            po.TotalCost = CalculateTotalCost(po);

            // Business Operation 2: validateBudget()
            ValidateBudget(po);

            // Business Operation 4: validatePurchaseOrder()
            await ValidatePurchaseOrderAsync(po);

            _context.PurchaseOrders.Add(po);
            await _context.SaveChangesAsync();

            // Record audit: PO created
            await RecordAuditAsync(po.Id, "PO created", createdById, "Purchase order initialized in Draft state.");

            // Create / update AI Validation workflow record
            await EnsurePoValidationWorkflowAsync(po);

            // Reload with navigation properties
            return (await GetByIdAsync(po.Id))!;
        }

        // ── Update ────────────────────────────────────────────────────────────────

        public async Task<PurchaseOrderResponseDto?> UpdateAsync(int id, UpdatePurchaseOrderDto dto)
        {
            var po = await _context.PurchaseOrders
                .Include(p => p.OrderLines)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (po is null) return null;

            if (po.Status != PurchaseOrderStatus.Draft)
                throw new InvalidOperationException(
                    $"Purchase Order can only be edited in Draft status. Current status: {po.Status}");

            // Business Operation 3: validateSupplier()
            await ValidateSupplierAsync(dto.SupplierId);

            po.SupplierId = dto.SupplierId;
            if (!string.IsNullOrWhiteSpace(dto.Currency))
                po.Currency = dto.Currency.Trim().ToUpperInvariant();
            po.BudgetLimit = dto.BudgetLimit;
            po.Notes = dto.Notes;
            po.UpdatedAt = DateTime.UtcNow;

            // Replace all order lines
            _context.OrderLines.RemoveRange(po.OrderLines);
            po.OrderLines.Clear();

            foreach (var lineDto in dto.Lines)
            {
                var line = new OrderLine
                {
                    RawMaterialId = lineDto.RawMaterialId > 0 ? lineDto.RawMaterialId : lineDto.MaterialId,
                    Description = lineDto.Description,
                    Quantity = lineDto.Quantity,
                    UnitPrice = lineDto.UnitPrice,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };
                line.TotalPrice = CalculateLineCost(line);
                po.OrderLines.Add(line);
            }

            // Recompute business rules
            po.TotalCost = CalculateTotalCost(po);
            ValidateBudget(po);
            await ValidatePurchaseOrderAsync(po);

            await _context.SaveChangesAsync();
            await EnsurePoValidationWorkflowAsync(po);
            return (await GetByIdAsync(po.Id))!;
        }

        /// <summary>
        /// DELETE /api/purchase-orders/{id} — Delete PO (Draft status only).
        /// </summary>
        public async Task<bool> DeleteAsync(int id)
        {
            var po = await _context.PurchaseOrders
                .Include(p => p.OrderLines)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (po == null) return false;

            if (po.Status != PurchaseOrderStatus.Draft)
            {
                throw new InvalidOperationException($"Purchase Order {po.PoNumber} cannot be deleted because it is in '{po.Status}' status. Only Draft purchase orders may be deleted.");
            }

            _context.OrderLines.RemoveRange(po.OrderLines);
            _context.PurchaseOrders.Remove(po);
            await _context.SaveChangesAsync();
            return true;
        }

        // ── OrderLine Sub-Resource CRUD (Requirement 5) ──────────────────────────

        public async Task<IEnumerable<OrderLineResponseDto>> GetOrderLinesAsync(int poId)
        {
            var po = await _context.PurchaseOrders
                .Include(p => p.OrderLines)
                    .ThenInclude(ol => ol.RawMaterial)
                .FirstOrDefaultAsync(p => p.Id == poId)
                ?? throw new KeyNotFoundException($"Purchase Order {poId} not found.");

            return po.OrderLines.Select(MapOrderLineToResponseDto);
        }

        public async Task<OrderLineResponseDto> AddOrderLineAsync(int poId, OrderLineDto dto)
        {
            var po = await _context.PurchaseOrders
                .Include(p => p.OrderLines)
                .FirstOrDefaultAsync(p => p.Id == poId)
                ?? throw new KeyNotFoundException($"Purchase Order {poId} not found.");

            if (po.Status != PurchaseOrderStatus.Draft)
                throw new InvalidOperationException($"Order lines can only be modified on Draft purchase orders. Current status: {po.Status}");

            var rawMaterialId = dto.RawMaterialId > 0 ? dto.RawMaterialId : dto.MaterialId;
            var material = await _context.RawMaterials.FindAsync(rawMaterialId)
                ?? throw new KeyNotFoundException($"RawMaterial {rawMaterialId} not found.");

            var line = new OrderLine
            {
                PurchaseOrderId = po.Id,
                RawMaterialId = rawMaterialId,
                Description = dto.Description,
                Quantity = dto.Quantity,
                UnitPrice = dto.UnitPrice,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            line.TotalPrice = CalculateLineCost(line);

            po.OrderLines.Add(line);
            po.TotalCost = CalculateTotalCost(po);
            ValidateBudget(po);
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            line.RawMaterial = material;
            return MapOrderLineToResponseDto(line);
        }

        public async Task<OrderLineResponseDto> UpdateOrderLineAsync(int poId, int lineId, OrderLineDto dto)
        {
            var po = await _context.PurchaseOrders
                .Include(p => p.OrderLines)
                    .ThenInclude(ol => ol.RawMaterial)
                .FirstOrDefaultAsync(p => p.Id == poId)
                ?? throw new KeyNotFoundException($"Purchase Order {poId} not found.");

            if (po.Status != PurchaseOrderStatus.Draft)
                throw new InvalidOperationException($"Order lines can only be modified on Draft purchase orders. Current status: {po.Status}");

            var line = po.OrderLines.FirstOrDefault(l => l.Id == lineId)
                ?? throw new KeyNotFoundException($"OrderLine {lineId} not found on Purchase Order {poId}.");

            var rawMaterialId = dto.RawMaterialId > 0 ? dto.RawMaterialId : dto.MaterialId;
            var material = await _context.RawMaterials.FindAsync(rawMaterialId)
                ?? throw new KeyNotFoundException($"RawMaterial {rawMaterialId} not found.");

            line.RawMaterialId = rawMaterialId;
            line.RawMaterial = material;
            line.Description = dto.Description;
            line.Quantity = dto.Quantity;
            line.UnitPrice = dto.UnitPrice;
            line.TotalPrice = CalculateLineCost(line);
            line.UpdatedAt = DateTime.UtcNow;

            po.TotalCost = CalculateTotalCost(po);
            ValidateBudget(po);
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return MapOrderLineToResponseDto(line);
        }

        public async Task<bool> DeleteOrderLineAsync(int poId, int lineId)
        {
            var po = await _context.PurchaseOrders
                .Include(p => p.OrderLines)
                .FirstOrDefaultAsync(p => p.Id == poId)
                ?? throw new KeyNotFoundException($"Purchase Order {poId} not found.");

            if (po.Status != PurchaseOrderStatus.Draft)
                throw new InvalidOperationException($"Order lines can only be modified on Draft purchase orders. Current status: {po.Status}");

            var line = po.OrderLines.FirstOrDefault(l => l.Id == lineId);
            if (line == null) return false;

            if (po.OrderLines.Count <= 1)
                throw new InvalidOperationException("Cannot remove the only order line. Purchase orders must have at least one line.");

            po.OrderLines.Remove(line);
            _context.OrderLines.Remove(line);

            po.TotalCost = CalculateTotalCost(po);
            ValidateBudget(po);
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return true;
        }

        private static OrderLineResponseDto MapOrderLineToResponseDto(OrderLine line)
        {
            return new OrderLineResponseDto
            {
                Id = line.Id,
                RawMaterialId = line.RawMaterialId,
                RawMaterialName = line.RawMaterial?.Name ?? $"Material #{line.RawMaterialId}",
                RawMaterialSku = line.RawMaterial?.SkuCode ?? string.Empty,
                Description = line.Description ?? string.Empty,
                Quantity = line.Quantity,
                UnitPrice = line.UnitPrice,
                TotalPrice = line.TotalPrice > 0 ? line.TotalPrice : line.Quantity * line.UnitPrice
            };
        }

        // ── Approval Workflow ─────────────────────────────────────────────────────

        public async Task<PurchaseOrderResponseDto> SubmitForApprovalAsync(int id, Guid? userId = null)
        {
            using var tx = await BeginTransactionIfSupportedAsync();

            var po = await LoadPoAsync(id);
            TransitionStatus(po, PurchaseOrderStatus.PendingApproval);
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            // Record audit: PO submitted
            await RecordAuditAsync(po.Id, "PO submitted", userId, "Submitted for manager authorization.");

            await EnsurePoValidationWorkflowAsync(po);

            if (tx is not null) await tx.CommitAsync();

            return (await GetByIdAsync(po.Id))!;
        }

        public async Task<PurchaseOrderResponseDto> ApproveAsync(int id, Guid approverId, string? notes = null)
        {
            var poToApprove = await LoadPoAsync(id);

            // 1. LIVE AI VALIDATION: Run the Validation/Safety Agent workflow for this PO right now
            await RunAiValidationWorkflowAsync(poToApprove);

            // 2. BACKEND APPROVAL GATE: Authoritative verification against PostgreSQL & QA state
            await ValidateApprovalGateAsync(poToApprove);

            int poId;
            using (var tx = await BeginTransactionIfSupportedAsync())
            {
                var po = await LoadPoAsync(id);
                TransitionStatus(po, PurchaseOrderStatus.Approved);

                po.ApprovedById = approverId;
                po.ApprovedAt = DateTime.UtcNow;
                po.UpdatedAt = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                // Record audit: PO approved
                await RecordAuditAsync(po.Id, "PO approved", approverId, notes ?? "Manager approved purchase order.");

                if (tx is not null) await tx.CommitAsync();
                poId = po.Id;
            }

            // Reload for sync
            var approvedPo = await LoadPoAsync(id);
            // PO is now in Approved status, ready for Manager Financial Settlement (Stripe or Bank Slip)
            await EnsurePoValidationWorkflowAsync(approvedPo);
            // Sync with AgentWorkflow if this PO was AI-generated
            try
            {
                if (!string.IsNullOrEmpty(approvedPo.Notes))
                {
                    var match = Regex.Match(approvedPo.Notes, @"(WF-[A-Za-z0-9_-]+)");
                    if (match.Success)
                    {
                        var wfId = match.Groups[1].Value;
                        var wf = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.WorkflowId == wfId);
                        if (wf != null)
                        {
                            wf.Status = WorkflowStatus.Completed;
                            wf.ApprovalStatus = ApprovalStatus.Approved;
                            wf.CurrentAgent = "Execution";
                            wf.CompletedAt = DateTime.UtcNow;
                            await _context.SaveChangesAsync();
                        }

                        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
                        await http.PostAsync($"http://localhost:8000/api/workflows/{wfId}/approve", null);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to sync approval to AI workflow for PO {Id}", id);
            }

            // Replenish inventory stock and resolve alerts
            if (_mfgContext != null)
            {
                await ReplenishInventoryAsync(approvedPo);
            }

            return (await GetByIdAsync(approvedPo.Id))!;
        }

        private async Task ReplenishInventoryAsync(PurchaseOrder po)
        {
            if (_mfgContext == null) return;

            try
            {
                var lines = po.OrderLines;
                if (lines == null || !lines.Any())
                {
                    lines = await _context.OrderLines.Where(l => l.PurchaseOrderId == po.Id).ToListAsync();
                }

                foreach (var line in lines)
                {
                    backend.Models.RawMaterial? material = null;
                    if (line.RawMaterialId > 0)
                    {
                        material = await _mfgContext.RawMaterials.FirstOrDefaultAsync(m => m.Id == line.RawMaterialId);
                    }

                    if (material == null && !string.IsNullOrEmpty(line.Description))
                    {
                        material = await _mfgContext.RawMaterials.FirstOrDefaultAsync(m => 
                            line.Description.Contains(m.SkuCode) || line.Description.Contains(m.Name));
                    }

                    if (material == null && !string.IsNullOrEmpty(po.Notes))
                    {
                        material = await _mfgContext.RawMaterials.FirstOrDefaultAsync(m => 
                            po.Notes.Contains(m.SkuCode) || po.Notes.Contains(m.Name));
                    }

                    material ??= await _mfgContext.RawMaterials.FirstOrDefaultAsync();

                    if (material != null)
                    {
                        // 1. Create newly received inventory roll
                        var rollId = $"ROLL-{DateTime.UtcNow:yyyyMMddHHmmss}-{new Random().Next(100, 999)}";
                        var newRoll = new backend.Models.InventoryRoll
                        {
                            Id = rollId,
                            RollIdentifier = rollId,
                            BatchId = "BATCH001",
                            RawMaterialId = material.Id,
                            InitialQuantity = line.Quantity,
                            CurrentQuantity = line.Quantity,
                            Status = "In Stock",
                            BarcodeUrl = $"https://api.qrserver.com/v1/create-qr-code/?size=150x150&data={rollId}",
                            ReceivedDate = DateTime.UtcNow,
                            CreatedAt = DateTime.UtcNow,
                            UpdatedAt = DateTime.UtcNow
                        };
                        _mfgContext.InventoryRolls.Add(newRoll);

                        // 2. Update StockLevel if present
                        var stockLevel = await _mfgContext.StockLevels.FirstOrDefaultAsync(s => s.RawMaterialId == material.Id);
                        if (stockLevel != null)
                        {
                            stockLevel.TotalQuantity += line.Quantity;
                            stockLevel.RecordedAt = DateTime.UtcNow;
                        }

                        // 3. Update legacy/general InventoryItem if exists
                        var item = await _mfgContext.InventoryItems.FirstOrDefaultAsync(i => 
                            i.Sku == material.SkuCode || i.Name.ToLower() == material.Name.ToLower());
                        if (item != null)
                        {
                            item.StockLevel += (int)line.Quantity;
                        }

                        // 4. Resolve any pending or in-progress alerts for this SKU!
                        var alerts = await _mfgContext.StockAlerts
                            .Where(a => a.Sku == material.SkuCode && (a.Status == "Pending" || a.Status == "Processing" || a.Status == "Acknowledged"))
                            .ToListAsync();

                        foreach (var a in alerts)
                        {
                            a.Status = "Resolved";
                        }

                        _logger.LogInformation("Replenished {Qty} units for raw material {Sku}. Created Roll {RollId} and resolved {AlertCount} alerts.", 
                            line.Quantity, material.SkuCode, rollId, alerts.Count);
                    }
                }

                await _mfgContext.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to automatically replenish inventory for PO {PoNumber}", po.PoNumber);
            }
        }

        public async Task<PurchaseOrderResponseDto> RejectAsync(int id, Guid approverId, string? reason)
        {
            using var tx = await BeginTransactionIfSupportedAsync();

            var po = await LoadPoAsync(id);
            TransitionStatus(po, PurchaseOrderStatus.Rejected);

            po.ApprovedById = approverId;
            po.ApprovedAt = DateTime.UtcNow;
            po.RejectionReason = reason;
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            // Record audit: PO rejected
            await RecordAuditAsync(po.Id, "PO rejected", approverId, $"Rejected: {reason}");

            if (tx is not null) await tx.CommitAsync();

            // Ensure AgentWorkflow status is synced
            await EnsurePoValidationWorkflowAsync(po);

            // Sync with AgentWorkflow if this PO was AI-generated
            try
            {
                if (!string.IsNullOrEmpty(po.Notes))
                {
                    var match = Regex.Match(po.Notes, @"(WF-[A-Za-z0-9_-]+)");
                    if (match.Success)
                    {
                        var wfId = match.Groups[1].Value;
                        var wf = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.WorkflowId == wfId);
                        if (wf != null)
                        {
                            wf.Status = WorkflowStatus.Failed;
                            wf.ApprovalStatus = ApprovalStatus.Rejected;
                            wf.CompletedAt = DateTime.UtcNow;
                            await _context.SaveChangesAsync();
                        }

                        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
                        await http.PostAsync($"http://localhost:8000/api/workflows/{wfId}/reject", null);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to sync rejection to AI workflow for PO {Id}", id);
            }

            return (await GetByIdAsync(po.Id))!;
        }

        public async Task<PurchaseOrderResponseDto> RequestRevisionAsync(int id, Guid approverId, string? reason)
        {
            using var tx = await BeginTransactionIfSupportedAsync();

            var po = await LoadPoAsync(id);
            TransitionStatus(po, PurchaseOrderStatus.RevisionRequested);

            po.ApprovedById = approverId;
            po.RejectionReason = reason;
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            // Record audit: PO revised
            await RecordAuditAsync(po.Id, "PO revised", approverId, $"Revision requested: {reason}");

            // Revert to Draft so requester can edit
            TransitionStatus(po, PurchaseOrderStatus.Draft);
            po.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            if (tx is not null) await tx.CommitAsync();

            return (await GetByIdAsync(po.Id))!;
        }

        // ── Business Operations (1, 2, 3, 4) ──────────────────────────────────────

        /// <summary>
        /// BUSINESS OPERATION 1: calculateTotalCost()
        /// Calculates total cost from OrderLines. Subtotal = Quantity × UnitPrice.
        /// TotalAmount = SUM(OrderLine.Subtotal).
        /// </summary>
        public decimal CalculateTotalCost(PurchaseOrder po)
        {
            if (po.OrderLines == null || !po.OrderLines.Any())
                return 0m;

            return Math.Round(po.OrderLines.Sum(line => line.TotalPrice > 0 ? line.TotalPrice : line.Quantity * line.UnitPrice), 2);
        }

        public static decimal CalculateLineCost(OrderLine line)
        {
            return Math.Round(line.Quantity * line.UnitPrice, 2);
        }

        /// <summary>
        /// BUSINESS OPERATION 2: validateBudget()
        /// Check:
        /// 1. department budget: PO amount <= budget limit
        /// 2. approval threshold: If PO > $5,000 -> RequiresApproval = true
        /// </summary>
        public void ValidateBudget(PurchaseOrder po)
        {
            if (po.BudgetLimit <= 0)
                throw new InvalidOperationException("Budget limit must be greater than zero.");

            if (po.TotalCost > po.BudgetLimit)
                throw new InvalidOperationException(
                    $"Total cost ({po.TotalCost:C}) exceeds budget limit ({po.BudgetLimit:C}). " +
                    "Reduce quantities or increase the budget limit.");

            // Check approval threshold ($5,000 default)
            po.RequiresApproval = po.TotalCost > po.ApprovalThreshold;
        }

        /// <summary>
        /// BUSINESS OPERATION 3: validateSupplier()
        /// Checks:
        /// - supplier exists
        /// - supplier is active
        /// - supplier has required contact information (email, phone, address)
        /// - supplier lead time > 0
        /// </summary>
        public async Task<Supplier> ValidateSupplierAsync(int supplierId)
        {
            var supplier = await _context.Suppliers.FindAsync(supplierId)
                ?? throw new KeyNotFoundException($"Supplier {supplierId} not found.");

            if (!supplier.IsActive)
                throw new InvalidOperationException($"Supplier '{supplier.Name}' is inactive and cannot receive orders.");

            if (string.IsNullOrWhiteSpace(supplier.ContactEmail))
                throw new InvalidOperationException($"Supplier '{supplier.Name}' lacks a valid contact email.");

            if (supplier.LeadTimeDays <= 0)
                throw new InvalidOperationException($"Supplier '{supplier.Name}' has an invalid lead time ({supplier.LeadTimeDays} days).");

            return supplier;
        }

        /// <summary>
        /// BUSINESS OPERATION 4: validatePurchaseOrder()
        /// Validates:
        /// - supplier exists and active
        /// - at least one order line
        /// - valid material, quantity > 0, unit price > 0
        /// - currency is specified
        /// - total cost computed and matches lines
        /// - budget constraints met
        /// - status validity
        /// - required fields
        /// </summary>
        public async Task ValidatePurchaseOrderAsync(PurchaseOrder po)
        {
            if (po.SupplierId <= 0)
                throw new InvalidOperationException("Purchase order must have a valid supplier assigned.");

            await ValidateSupplierAsync(po.SupplierId);

            if (po.OrderLines == null || !po.OrderLines.Any())
                throw new InvalidOperationException("Purchase order must have at least one order line.");

            foreach (var line in po.OrderLines)
            {
                if (line.RawMaterialId <= 0)
                    throw new InvalidOperationException("Each order line must reference a valid raw material.");

                if (line.Quantity <= 0)
                    throw new InvalidOperationException("Order line quantity must be strictly greater than zero.");

                if (line.UnitPrice <= 0)
                    throw new InvalidOperationException("Order line unit price must be strictly greater than zero.");
            }

            if (string.IsNullOrWhiteSpace(po.Currency))
                throw new InvalidOperationException("Currency must be specified.");

            if (po.TotalCost <= 0)
                throw new InvalidOperationException("Total cost must be strictly positive.");

            ValidateBudget(po);
        }

        /// <summary>
        /// BACKEND APPROVAL GATE: Authoritative verification against PostgreSQL state,
        /// ensuring active supplier, valid math/lines, and that any QA/quarantine issue
        /// has been manually resolved and quarantine released before approval is granted.
        /// </summary>
        public async Task ValidateApprovalGateAsync(PurchaseOrder po)
        {
            // 1. Authoritative check on Supplier master catalog in PostgreSQL
            var supplier = await _context.Suppliers.FindAsync(po.SupplierId);
            if (supplier == null)
            {
                throw new InvalidOperationException($"Approval blocked: Supplier {po.SupplierId} not found.");
            }
            if (!supplier.IsActive)
            {
                var suppIdent = !string.IsNullOrWhiteSpace(supplier.SupplierCode) ? supplier.SupplierCode : supplier.Name;
                throw new InvalidOperationException($"Approval blocked: Validation failed because supplier {suppIdent} is inactive.");
            }

            // 2. Order lines validation
            if (po.OrderLines == null || !po.OrderLines.Any())
            {
                po.OrderLines = await _context.OrderLines.Where(l => l.PurchaseOrderId == po.Id).ToListAsync();
            }

            if (po.OrderLines == null || !po.OrderLines.Any())
            {
                throw new InvalidOperationException("Approval blocked: Purchase order must have at least one order line.");
            }

            foreach (var line in po.OrderLines)
            {
                if (line.Quantity <= 0)
                {
                    throw new InvalidOperationException("Approval blocked: Order line quantity must be strictly greater than zero.");
                }
                if (line.UnitPrice <= 0)
                {
                    throw new InvalidOperationException("Approval blocked: Order line unit price must be strictly greater than zero.");
                }

                var expectedLineTotal = Math.Round(line.Quantity * line.UnitPrice, 2);
                if (line.TotalPrice > 0 && Math.Abs(line.TotalPrice - expectedLineTotal) > 0.05m)
                {
                    throw new InvalidOperationException("Approval blocked: PO financial calculation mismatch detected.");
                }
            }

            // 3. Find associated AgentWorkflow (AI Validation / QA)
            AgentWorkflow? wf = null;
            if (!string.IsNullOrEmpty(po.Notes))
            {
                var match = Regex.Match(po.Notes, @"(WF-[A-Za-z0-9_-]+)");
                if (match.Success)
                {
                    var wfId = match.Groups[1].Value;
                    wf = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.WorkflowId == wfId);
                }
            }

            if (wf == null)
            {
                var candidates = new[] { $"WF-QA-{po.PoNumber}", $"WF-{po.PoNumber}", $"WF-2026-{(100 + po.Id):D3}", $"WF-{po.Id}" };
                wf = await _context.AgentWorkflows.FirstOrDefaultAsync(w => candidates.Contains(w.WorkflowId));
            }

            // If no workflow or validation results exist yet, generate them dynamically
            if (wf == null || string.IsNullOrWhiteSpace(wf.ValidationResults))
            {
                wf = await RunAiValidationWorkflowAsync(po);
            }

            // 4. Authoritative check on AI ValidationResults if present
            if (wf != null && !string.IsNullOrWhiteSpace(wf.ValidationResults))
            {
                try
                {
                    using var doc = JsonDocument.Parse(wf.ValidationResults);
                    var root = doc.RootElement;

                    // Supplier validation check
                    if (root.TryGetProperty("supplierValidation", out var sv) && sv.GetString() == "INACTIVE_SUPPLIER")
                    {
                        var suppIdent = !string.IsNullOrWhiteSpace(supplier.SupplierCode) ? supplier.SupplierCode : supplier.Name;
                        throw new InvalidOperationException($"Approval blocked: Validation failed because supplier {suppIdent} is inactive.");
                    }

                    // PO Math check
                    if (root.TryGetProperty("poMathematicalCheck", out var pm) && pm.GetString() == "CALCULATION_MISMATCH")
                    {
                        throw new InvalidOperationException("Approval blocked: PO financial calculation mismatch detected.");
                    }

                    // Material validation
                    if (root.TryGetProperty("materialValidation", out var mv))
                    {
                        var matStr = mv.GetString();
                        if (matStr != null && matStr.StartsWith("INVALID", StringComparison.OrdinalIgnoreCase))
                        {
                            throw new InvalidOperationException("Approval blocked: Validation failed because material is invalid.");
                        }
                    }

                    var qualitySafetyStatus = root.TryGetProperty("qualitySafetyStatus", out var qs) ? qs.GetString() : null;
                    var manualResolutionStatus = root.TryGetProperty("manualResolutionStatus", out var mr) ? mr.GetString() : null;
                    var rejectionReason = root.TryGetProperty("rejectionReason", out var rr) ? rr.GetString() : null;
                    var isValid = root.TryGetProperty("isValid", out var iv) && iv.ValueKind == JsonValueKind.True;

                    bool isQuarantineRequired = qualitySafetyStatus == "QUARANTINE_REQUIRED" || qualitySafetyStatus == "QUARANTINE_ACTIVE";

                    if (isQuarantineRequired)
                    {
                        // 4a. Check if QualityInspector has provided manual resolution
                        if (manualResolutionStatus != "RESOLVED")
                        {
                            throw new InvalidOperationException("Approval blocked: QA validation requires manual review.");
                        }

                        // 4b. Recheck CURRENT PostgreSQL state for active quarantine holds
                        var hasActiveQuarantines = await _context.Quarantines.AnyAsync(q => q.Status == QuarantineStatus.Active);
                        if (hasActiveQuarantines)
                        {
                            throw new InvalidOperationException("Approval blocked: Associated inventory is still quarantined.");
                        }
                    }
                    else if (!isValid && manualResolutionStatus != "RESOLVED")
                    {
                        var reason = !string.IsNullOrWhiteSpace(rejectionReason) ? rejectionReason : "QA validation requires manual review.";
                        throw new InvalidOperationException($"Approval blocked: {reason}");
                    }
                }
                catch (InvalidOperationException)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Could not parse ValidationResults for workflow {WorkflowId}", wf.WorkflowId);
                }
            }
        }

        /// <summary>
        /// Invokes the Python AI Validation / Safety Agent workflow at http://localhost:8000/api/workflows/run
        /// for the specified Purchase Order, persisting the newly produced validation assessment.
        /// </summary>
        public async Task<AgentWorkflow> RunAiValidationWorkflowAsync(PurchaseOrder po)
        {
            string workflowId;
            if (!string.IsNullOrWhiteSpace(po.Notes) && Regex.IsMatch(po.Notes, @"(WF-[A-Za-z0-9_-]+)"))
            {
                workflowId = Regex.Match(po.Notes, @"(WF-[A-Za-z0-9_-]+)").Groups[1].Value;
            }
            else
            {
                workflowId = $"WF-QA-{po.PoNumber}";
                if (string.IsNullOrWhiteSpace(po.Notes))
                {
                    po.Notes = $"Workflow ID: {workflowId}";
                }
                else if (!po.Notes.Contains("WF-"))
                {
                    po.Notes = $"{po.Notes} [Workflow ID: {workflowId}]";
                }
            }

            if (po.OrderLines == null || !po.OrderLines.Any())
            {
                po.OrderLines = await _context.OrderLines.Where(l => l.PurchaseOrderId == po.Id).ToListAsync();
            }

            var supplier = po.Supplier ?? await _context.Suppliers.FindAsync(po.SupplierId);
            var firstLine = po.OrderLines?.FirstOrDefault();
            var totalQty = po.OrderLines?.Sum(l => l.Quantity) ?? 1000m;
            var unitPrice = firstLine?.UnitPrice ?? 0m;
            var budgetCap = po.BudgetLimit > 0 ? po.BudgetLimit : 5000m;

            try
            {
                using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
                var payload = new
                {
                    objective = $"Validation & quality safety assessment for PO {po.PoNumber}",
                    workflowId = workflowId,
                    material_id = firstLine?.RawMaterialId.ToString() ?? "1",
                    required_quantity = (double)totalQty,
                    purchasing_data = new
                    {
                        draft_po = new
                        {
                            poNumber = po.PoNumber,
                            supplierId = po.SupplierId.ToString(),
                            supplier = supplier?.Name ?? $"SUP-{po.SupplierId}",
                            materialId = firstLine?.RawMaterialId.ToString() ?? "1",
                            quantity = (double)totalQty,
                            unitPrice = (double)unitPrice,
                            totalAmount = (double)po.TotalCost,
                            budgetThreshold = (double)budgetCap
                        }
                    }
                };

                var content = new StringContent(JsonSerializer.Serialize(payload), System.Text.Encoding.UTF8, "application/json");
                var response = await client.PostAsync("http://localhost:8000/api/workflows/run", content);
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Successfully executed AI Validation/Safety agent workflow for PO {PoNumber}", po.PoNumber);
                    var syncedWf = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.WorkflowId == workflowId);
                    if (syncedWf != null && !string.IsNullOrWhiteSpace(syncedWf.ValidationResults))
                    {
                        return syncedWf;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "FastAPI agent workflow execution unavailable, falling back to authoritative database validation for PO {PoNumber}", po.PoNumber);
            }

            return await EnsurePoValidationWorkflowAsync(po);
        }

        /// <summary>
        /// Generates and persists the AI Validation & Safety Agent assessment into PostgreSQL AgentWorkflows.
        /// Ensures all 14 schema properties are computed and immediately available in Quality History.
        /// </summary>
        public async Task<AgentWorkflow> EnsurePoValidationWorkflowAsync(PurchaseOrder po)
        {
            // 1. Identify Workflow ID
            string workflowId;
            if (!string.IsNullOrWhiteSpace(po.Notes) && Regex.IsMatch(po.Notes, @"(WF-[A-Za-z0-9_-]+)"))
            {
                workflowId = Regex.Match(po.Notes, @"(WF-[A-Za-z0-9_-]+)").Groups[1].Value;
            }
            else
            {
                workflowId = $"WF-QA-{po.PoNumber}";
                if (string.IsNullOrWhiteSpace(po.Notes))
                {
                    po.Notes = $"Workflow ID: {workflowId}";
                }
                else if (!po.Notes.Contains("WF-"))
                {
                    po.Notes = $"{po.Notes} [Workflow ID: {workflowId}]";
                }
            }

            var existingWf = await _context.AgentWorkflows.FirstOrDefaultAsync(w => 
                w.WorkflowId == workflowId || 
                w.WorkflowId == $"WF-QA-{po.PoNumber}" || 
                w.WorkflowId == $"WF-{po.PoNumber}" || 
                w.WorkflowId == $"WF-2026-{(100 + po.Id):D3}");

            // 2. Validate Supplier against PostgreSQL ERP master catalog
            var supplier = po.Supplier ?? await _context.Suppliers.FindAsync(po.SupplierId);
            string supplierValidation = "PASSED";
            bool isValid = true;
            string? rejectionReason = null;

            if (supplier == null || !supplier.IsActive)
            {
                supplierValidation = "INACTIVE_SUPPLIER";
                isValid = false;
                var sName = supplier?.Name ?? $"SUP-{po.SupplierId}";
                rejectionReason = $"Supplier '{sName}' is inactive in ERP master catalog.";
            }

            // 3. Validate Budget
            string budgetCheck = "PASSED";
            if (po.BudgetLimit > 0 && po.TotalCost > po.BudgetLimit)
            {
                budgetCheck = "BUDGET_EXCEEDED";
                isValid = false;
                rejectionReason ??= $"Total order cost (${po.TotalCost:N2}) exceeds authorized budget limit (${po.BudgetLimit:N2}).";
            }

            // 4. Validate Order Lines & Math
            if (po.OrderLines == null || !po.OrderLines.Any())
            {
                po.OrderLines = await _context.OrderLines.Where(l => l.PurchaseOrderId == po.Id).ToListAsync();
            }

            string poMathematicalCheck = "PASSED";
            if (po.OrderLines == null || !po.OrderLines.Any() || po.TotalCost <= 0)
            {
                poMathematicalCheck = "CALCULATION_MISMATCH";
                isValid = false;
                rejectionReason ??= "PO total cost or line quantities are invalid.";
            }
            else
            {
                foreach (var line in po.OrderLines)
                {
                    if (line.Quantity <= 0 || line.UnitPrice <= 0)
                    {
                        poMathematicalCheck = "CALCULATION_MISMATCH";
                        isValid = false;
                        rejectionReason ??= "Order line quantity and unit price must be strictly positive.";
                        break;
                    }
                    var expected = Math.Round(line.Quantity * line.UnitPrice, 2);
                    if (line.TotalPrice > 0 && Math.Abs(line.TotalPrice - expected) > 0.05m)
                    {
                        poMathematicalCheck = "CALCULATION_MISMATCH";
                        isValid = false;
                        rejectionReason ??= $"Calculation mismatch: {line.Quantity} x ${line.UnitPrice:N2} != ${line.TotalPrice:N2}";
                        break;
                    }
                }
            }

            // 5. Material & Quality / Quarantine Safety Check
            string materialValidation = "PASSED";
            string qualitySafetyStatus = "CLEAR";
            int quarantinedRollsCount = 0;

            var activeQuarantines = await _context.Quarantines
                .Where(q => q.Status == QuarantineStatus.Active)
                .ToListAsync();

            if (activeQuarantines.Any())
            {
                quarantinedRollsCount = activeQuarantines.Count;
                qualitySafetyStatus = "QUARANTINE_ACTIVE";
                isValid = false;
            }

            // 6. Impact Assessment
            bool isHighImpact = po.TotalCost > 1000m || qualitySafetyStatus == "QUARANTINE_ACTIVE" || qualitySafetyStatus == "QUARANTINE_REQUIRED" || !isValid;
            string? impactReason = null;
            if (!isValid && !string.IsNullOrWhiteSpace(rejectionReason))
            {
                impactReason = rejectionReason;
            }
            else if (qualitySafetyStatus == "QUARANTINE_ACTIVE" || qualitySafetyStatus == "QUARANTINE_REQUIRED")
            {
                impactReason = $"{quarantinedRollsCount} inventory roll(s) currently held in quarantine. Quality inspection required.";
            }
            else if (po.TotalCost > 5000m)
            {
                impactReason = $"High expenditure (${po.TotalCost:N2}) requires managerial authorization.";
            }
            else
            {
                impactReason = $"Procurement order (${po.TotalCost:N2}) within standard operational parameters.";
            }

            // 7. Manual resolution state handling (strictly authoritative from current DB state)
            string? manualResolutionStatus = null;
            string? manualResolutionNote = null;
            string? resolvedBy = null;
            string? resolvedAt = null;

            if (activeQuarantines.Any())
            {
                // Active blocking quarantine exists: resolution MUST be PENDING_REVIEW, never stale RESOLVED.
                manualResolutionStatus = "PENDING_REVIEW";
            }
            else
            {
                // No active quarantines. If this specific workflow was previously resolved after quarantine release, preserve it.
                if (existingWf != null && !string.IsNullOrWhiteSpace(existingWf.ValidationResults))
                {
                    try
                    {
                        using var doc = JsonDocument.Parse(existingWf.ValidationResults);
                        var root = doc.RootElement;
                        var prevStatus = root.TryGetProperty("manualResolutionStatus", out var mrs) ? mrs.GetString() : null;
                        if (prevStatus == "RESOLVED")
                        {
                            manualResolutionStatus = "RESOLVED";
                            if (root.TryGetProperty("manualResolutionNote", out var mrn)) manualResolutionNote = mrn.GetString();
                            if (root.TryGetProperty("resolvedBy", out var rb)) resolvedBy = rb.GetString();
                            if (root.TryGetProperty("resolvedAt", out var ra)) resolvedAt = ra.GetString();
                        }
                    }
                    catch { }
                }

                if (manualResolutionStatus == null)
                {
                    manualResolutionStatus = isValid ? "NOT_REQUIRED" : "PENDING_REVIEW";
                }
            }

            // 8. Build JSON
            var validationDict = new Dictionary<string, object?>
            {
                ["isValid"] = isValid,
                ["qualitySafetyStatus"] = qualitySafetyStatus,
                ["supplierValidation"] = supplierValidation,
                ["budgetCheck"] = budgetCheck,
                ["poMathematicalCheck"] = poMathematicalCheck,
                ["materialValidation"] = materialValidation,
                ["quarantinedRollsCount"] = quarantinedRollsCount,
                ["isHighImpact"] = isHighImpact,
                ["impactReason"] = impactReason,
                ["rejectionReason"] = rejectionReason,
                ["manualResolutionStatus"] = manualResolutionStatus,
                ["manualResolutionNote"] = manualResolutionNote,
                ["resolvedBy"] = resolvedBy,
                ["resolvedAt"] = resolvedAt
            };

            var json = JsonSerializer.Serialize(validationDict);

            // 9. Save or Update AgentWorkflow
            if (existingWf != null)
            {
                existingWf.ValidationResults = json;
                if (po.Status == PurchaseOrderStatus.Approved || po.Status == PurchaseOrderStatus.Payment || po.Status == PurchaseOrderStatus.Sent)
                {
                    existingWf.Status = WorkflowStatus.Completed;
                    existingWf.ApprovalStatus = ApprovalStatus.Approved;
                    existingWf.CompletedAt = DateTime.UtcNow;
                    existingWf.FinalOutcome = $"PO {po.PoNumber} approved & dispatched (${po.TotalCost:F2})";
                }
                else if (po.Status == PurchaseOrderStatus.Rejected)
                {
                    existingWf.Status = WorkflowStatus.Failed;
                    existingWf.ApprovalStatus = ApprovalStatus.Rejected;
                    existingWf.CompletedAt = DateTime.UtcNow;
                    existingWf.FinalOutcome = $"PO {po.PoNumber} rejected: {po.RejectionReason}";
                }
                else
                {
                    existingWf.Status = WorkflowStatus.WaitingForApproval;
                    existingWf.ApprovalStatus = ApprovalStatus.Pending;
                    existingWf.CurrentAgent = "Validation/Safety";
                }
                await _context.SaveChangesAsync();
                return existingWf;
            }
            else
            {
                var newWf = new AgentWorkflow
                {
                    Id = Guid.NewGuid(),
                    WorkflowId = workflowId,
                    Objective = $"Autonomous validation & procurement safety assessment for PO {po.PoNumber}",
                    CurrentAgent = (po.Status == PurchaseOrderStatus.Approved || po.Status == PurchaseOrderStatus.Sent) ? "Execution" : "Validation/Safety",
                    Status = (po.Status == PurchaseOrderStatus.Approved || po.Status == PurchaseOrderStatus.Sent) ? WorkflowStatus.Completed : (po.Status == PurchaseOrderStatus.Rejected ? WorkflowStatus.Failed : WorkflowStatus.WaitingForApproval),
                    ApprovalStatus = (po.Status == PurchaseOrderStatus.Approved || po.Status == PurchaseOrderStatus.Sent) ? ApprovalStatus.Approved : (po.Status == PurchaseOrderStatus.Rejected ? ApprovalStatus.Rejected : ApprovalStatus.Pending),
                    StartedAt = po.CreatedAt,
                    CompletedAt = (po.Status == PurchaseOrderStatus.Approved || po.Status == PurchaseOrderStatus.Sent) ? po.UpdatedAt : null,
                    FinalOutcome = (po.Status == PurchaseOrderStatus.Approved || po.Status == PurchaseOrderStatus.Sent) ? $"PO {po.PoNumber} approved & dispatched (${po.TotalCost:F2})" : null,
                    ValidationResults = json
                };
                _context.AgentWorkflows.Add(newWf);
                await _context.SaveChangesAsync();
                return newWf;
            }
        }

        // ── State Machine Transition ──────────────────────────────────────────────

        /// <summary>
        /// State machine enforcement: throws InvalidOperationException on invalid transitions.
        /// </summary>
        private static void TransitionStatus(PurchaseOrder po, PurchaseOrderStatus target)
        {
            if (!PurchaseOrderStatusTransitions.IsTransitionAllowed(po.Status, target))
                throw new InvalidOperationException(
                    $"Invalid status transition: {po.Status} → {target}. " +
                    "This transition is not permitted by the business workflow.");

            po.Status = target;
        }

        // ── Payment & Email ───────────────────────────────────────────────────────

        /// <summary>
        /// Public payment settlement entrypoint for orders in Approved or Payment status.
        /// </summary>
        public async Task<PurchaseOrderResponseDto> ProcessPaymentAsync(int id, Guid? approverId = null, bool forceDispatch = false)
        {
            var po = await LoadPoAsync(id);
            if (po.Status == PurchaseOrderStatus.Paid || po.Status == PurchaseOrderStatus.Sent || po.Status == PurchaseOrderStatus.Delivered || po.Status == PurchaseOrderStatus.Completed)
            {
                return (await GetByIdAsync(id))!;
            }
            if (po.Status != PurchaseOrderStatus.Payment && po.Status != PurchaseOrderStatus.Approved && po.Status != PurchaseOrderStatus.PaymentFailed)
            {
                throw new InvalidOperationException(
                    $"Purchase Order must be in Approved or Payment status to process payment. Current status is {po.Status}.");
            }

            await ProcessPaymentInternalAsync(po, approverId, forceDispatch);
            return (await GetByIdAsync(id))!;
        }

        /// <summary>
        /// Triggered after Approve or manual settlement. Calls Stripe (sandbox fallback if placeholder key), handles failure safely.
        /// </summary>
        private async Task ProcessPaymentInternalAsync(PurchaseOrder po, Guid? approverId = null, bool forceDispatch = false)
        {
            using (var tx = await BeginTransactionIfSupportedAsync())
            {
                if (po.Status != PurchaseOrderStatus.Payment)
                {
                    TransitionStatus(po, PurchaseOrderStatus.Payment);
                    po.UpdatedAt = DateTime.UtcNow;
                    await _context.SaveChangesAsync();
                }

                // Record audit: payment started
                await RecordAuditAsync(po.Id, "payment started", approverId, "Stripe sandbox payment initiation.");

                if (tx is not null) await tx.CommitAsync();
            }

            var description = $"Purchase Order {po.PoNumber}";
            var currency = string.IsNullOrWhiteSpace(po.Currency) ? DefaultCurrency : po.Currency.ToLowerInvariant();
            var result = await _stripeService.CreatePaymentIntentAsync(po.TotalCost, currency, description);

            using (var tx = await BeginTransactionIfSupportedAsync())
            {
                po.StripePaymentIntentId = result.PaymentIntentId;
                po.StripePaymentStatus = result.Status;
                po.UpdatedAt = DateTime.UtcNow;

                // Record PaymentTransaction
                var txRecord = new PaymentTransaction
                {
                    PurchaseOrderId = po.Id,
                    TransactionId = result.PaymentIntentId,
                    Amount = po.TotalCost,
                    Currency = currency,
                    PaymentStatus = result.Status ?? (result.Success ? "succeeded" : "failed"),
                    FailureReason = result.ErrorMessage,
                    Timestamp = DateTime.UtcNow
                };
                _context.PaymentTransactions.Add(txRecord);

                if (!result.Success)
                {
                    po.PaymentFailureReason = result.ErrorMessage;
                    TransitionStatus(po, PurchaseOrderStatus.PaymentFailed);
                    await _context.SaveChangesAsync();

                    // Record audit: payment failed
                    await RecordAuditAsync(po.Id, "payment failed", approverId, $"Stripe failure: {result.ErrorMessage}");

                    if (tx is not null) await tx.CommitAsync();

                    _logger.LogWarning(
                        "Stripe payment failed for PO {PoNumber}: {Error}. Status transitioned to PaymentFailed.",
                        po.PoNumber, result.ErrorMessage);
                    return;
                }

                // Clear previous failure reasons on success
                po.PaymentFailureReason = null;
                TransitionStatus(po, PurchaseOrderStatus.Paid);
                await _context.SaveChangesAsync();

                // Record audit: payment completed
                await RecordAuditAsync(po.Id, "payment completed", approverId, $"Transaction ID: {result.PaymentIntentId}");

                if (tx is not null) await tx.CommitAsync();
            }

            // Payment succeeded — generate PDF and email
            await SendPoEmailAsync(po, approverId, forceDispatch);
        }

        /// <summary>
        /// Generates PO PDF using iText7, sends via SendGrid/EmailService.
        /// In dev/evaluation environments, forceDispatch allows advancing to Sent if SMTP is unavailable.
        /// </summary>
        private async Task SendPoEmailAsync(PurchaseOrder po, Guid? approverId = null, bool forceDispatch = false)
        {
            var poFull = await _context.PurchaseOrders
                .Include(p => p.Supplier)
                .Include(p => p.OrderLines)
                    .ThenInclude(ol => ol.RawMaterial)
                .FirstOrDefaultAsync(p => p.Id == po.Id);

            if (poFull is null) return;

            try
            {
                // Generate PDF
                var pdfBytes = GeneratePoPdf(poFull);
                var fileName = $"{poFull.PoNumber}.pdf";

                // Send email via existing EmailService
                await _emailService.SendPurchaseOrderEmailAsync(
                    poFull.Supplier.ContactEmail,
                    poFull.Supplier.Name,
                    poFull.PoNumber,
                    pdfBytes,
                    fileName);

                using (var tx = await BeginTransactionIfSupportedAsync())
                {
                    // Advance to Sent only after successful email
                    TransitionStatus(poFull, PurchaseOrderStatus.Sent);
                    poFull.EmailStatus = "Sent";
                    poFull.EmailSentAt = DateTime.UtcNow;
                    poFull.EmailFailureReason = null;
                    poFull.UpdatedAt = DateTime.UtcNow;
                    await _context.SaveChangesAsync();

                    // Record audit: email sent
                    await RecordAuditAsync(poFull.Id, "email sent", approverId, $"PO dispatched to {poFull.Supplier.ContactEmail}.");

                    if (tx is not null) await tx.CommitAsync();
                }

                _logger.LogInformation("PO {PoNumber} sent to {Email}", poFull.PoNumber, poFull.Supplier.ContactEmail);
            }
            catch (Exception ex)
            {
                poFull.EmailStatus = "Failed";
                poFull.EmailFailureReason = ex.Message;
                poFull.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                // Record audit: email failed
                await RecordAuditAsync(poFull.Id, "email failed", approverId, $"Dispatch error: {ex.Message}");

                _logger.LogError(ex, "Failed to send PO email for {PoNumber}. Status stays at Payment.", poFull.PoNumber);

                // If forceDispatch is active in dev/sandbox evaluation, complete the transition to Sent
                if (forceDispatch)
                {
                    using (var tx = await BeginTransactionIfSupportedAsync())
                    {
                        TransitionStatus(poFull, PurchaseOrderStatus.Sent);
                        poFull.EmailStatus = "Sent (Sandbox Dispatch)";
                        poFull.EmailSentAt = DateTime.UtcNow;
                        poFull.UpdatedAt = DateTime.UtcNow;
                        await _context.SaveChangesAsync();

                        await RecordAuditAsync(poFull.Id, "email sent (sandbox)", approverId, $"Sandbox evaluation dispatch completed. Note: {ex.Message}");

                        if (tx is not null) await tx.CommitAsync();
                    }

                    _logger.LogInformation("PO {PoNumber} advanced to Sent via sandbox dispatch fallback.", poFull.PoNumber);
                }
            }
        }

        // ── PDF Generation ────────────────────────────────────────────────────────

        public async Task<byte[]> GeneratePdfAsync(int id)
        {
            var poFull = await _context.PurchaseOrders
                .Include(p => p.Supplier)
                .Include(p => p.ApprovedBy)
                .Include(p => p.CreatedBy)
                .Include(p => p.OrderLines)
                    .ThenInclude(ol => ol.RawMaterial)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (poFull is null)
                throw new KeyNotFoundException($"Purchase Order {id} not found.");

            return GeneratePoPdf(poFull);
        }

        public static byte[] GeneratePoPdf(PurchaseOrder po)
        {
            byte[] pdfBytes;
            using (var ms = new MemoryStream())
            {
                using (var writer = new PdfWriter(ms))
                using (var pdf = new PdfDocument(writer))
                using (var doc = new Document(pdf))
                {
                    // Set margins: 36pt (0.5 inch)
                    doc.SetMargins(36, 36, 36, 36);

                    // Color palette
                    var darkSlate = new DeviceRgb(15, 23, 42);   // #0f172a
                    var brandBlue = new DeviceRgb(37, 99, 235);  // #2563eb
                    var emeraldGreen = new DeviceRgb(5, 150, 105); // #059669
                    var grayText = new DeviceRgb(100, 116, 139); // #64748b
                    var bgLight = new DeviceRgb(248, 250, 252);  // #f8fafc
                    var borderLight = new DeviceRgb(226, 232, 240); // #e2e8f0

                    // 1. Header Table (Two Columns)
                    var headerTable = new Table(UnitValue.CreatePercentArray(new float[] { 60, 40 })).UseAllAvailableWidth();
                    headerTable.SetBorder(Border.NO_BORDER);

                    var brandCell = new Cell().SetBorder(Border.NO_BORDER);
                    brandCell.Add(new Paragraph("AUTOMATED MANUFACTURING INVENTORY COORDINATOR")
                        .SetFontSize(13).SetBold().SetFontColor(darkSlate));
                    brandCell.Add(new Paragraph("Precision Manufacturing & Supply Chain Operations")
                        .SetFontSize(8.5f).SetFontColor(grayText));
                    brandCell.Add(new Paragraph("OFFICIAL PURCHASE ORDER")
                        .SetFontSize(16).SetBold().SetFontColor(brandBlue).SetMarginTop(6));
                    headerTable.AddCell(brandCell);

                    var poMetaCell = new Cell().SetBorder(Border.NO_BORDER).SetTextAlignment(TextAlignment.RIGHT);
                    poMetaCell.Add(new Paragraph($"ORDER: {po.PoNumber}")
                        .SetFontSize(12).SetBold().SetFontColor(darkSlate));
                    poMetaCell.Add(new Paragraph($"Date: {po.CreatedAt:yyyy-MM-dd HH:mm} UTC")
                        .SetFontSize(8.5f).SetFontColor(grayText));
                    poMetaCell.Add(new Paragraph($"Status: {po.Status.ToString().ToUpperInvariant()}")
                        .SetFontSize(9.5f).SetBold().SetFontColor(po.Status == PurchaseOrderStatus.Sent ? emeraldGreen : brandBlue));
                    poMetaCell.Add(new Paragraph($"Currency: {(string.IsNullOrWhiteSpace(po.Currency) ? "USD" : po.Currency.ToUpperInvariant())}")
                        .SetFontSize(8.5f).SetFontColor(grayText));
                    headerTable.AddCell(poMetaCell);

                    doc.Add(headerTable);
                    doc.Add(new Paragraph(" ").SetFontSize(4));

                    // 2. Vendor & Buyer Details Box
                    var partiesTable = new Table(UnitValue.CreatePercentArray(new float[] { 50, 50 })).UseAllAvailableWidth();
                    partiesTable.SetBorder(new SolidBorder(borderLight, 1));
                    partiesTable.SetBackgroundColor(bgLight);

                    var supplierCell = new Cell().SetBorder(Border.NO_BORDER).SetPadding(10);
                    supplierCell.Add(new Paragraph("VENDOR / SUPPLIER:")
                        .SetFontSize(8.5f).SetBold().SetFontColor(darkSlate));
                    supplierCell.Add(new Paragraph(po.Supplier?.Name ?? "Designated Industrial Supplier")
                        .SetFontSize(11).SetBold().SetFontColor(darkSlate));
                    supplierCell.Add(new Paragraph($"Vendor Code: {po.Supplier?.SupplierCode ?? $"SUP-{po.SupplierId}"}")
                        .SetFontSize(8.5f).SetFontColor(grayText));
                    supplierCell.Add(new Paragraph($"Contact Email: {po.Supplier?.ContactEmail ?? "procurement@vendor.com"}")
                        .SetFontSize(8.5f).SetFontColor(grayText));
                    if (!string.IsNullOrWhiteSpace(po.Supplier?.ContactPhone))
                        supplierCell.Add(new Paragraph($"Phone: {po.Supplier.ContactPhone}").SetFontSize(8.5f).SetFontColor(grayText));
                    if (!string.IsNullOrWhiteSpace(po.Supplier?.Address))
                        supplierCell.Add(new Paragraph($"Address: {po.Supplier.Address}").SetFontSize(8.5f).SetFontColor(grayText));
                    if (!string.IsNullOrWhiteSpace(po.Supplier?.PaymentTerms))
                        supplierCell.Add(new Paragraph($"Payment Terms: {po.Supplier.PaymentTerms}").SetFontSize(8.5f).SetFontColor(brandBlue));
                    partiesTable.AddCell(supplierCell);

                    var buyerCell = new Cell().SetBorder(Border.NO_BORDER).SetPadding(10);
                    buyerCell.Add(new Paragraph("BILL TO & SHIP TO:")
                        .SetFontSize(8.5f).SetBold().SetFontColor(darkSlate));
                    buyerCell.Add(new Paragraph("Automated Manufacturing Inventory Coordinator")
                        .SetFontSize(11).SetBold().SetFontColor(darkSlate));
                    buyerCell.Add(new Paragraph("Central Industrial Complex — Receiving Dock #1")
                        .SetFontSize(8.5f).SetFontColor(grayText));
                    buyerCell.Add(new Paragraph($"Approved By: {po.ApprovedBy?.FullName ?? "Supply Chain Manager"}")
                        .SetFontSize(8.5f).SetFontColor(grayText));
                    buyerCell.Add(new Paragraph($"Payment Settlement: Stripe ({(po.StripePaymentStatus ?? "Completed")})")
                        .SetFontSize(8.5f).SetBold().SetFontColor(emeraldGreen));
                    if (!string.IsNullOrWhiteSpace(po.StripePaymentIntentId))
                        buyerCell.Add(new Paragraph($"Stripe Ref: {po.StripePaymentIntentId}").SetFontSize(8).SetFontColor(grayText));
                    partiesTable.AddCell(buyerCell);

                    doc.Add(partiesTable);
                    doc.Add(new Paragraph(" ").SetFontSize(6));

                    // 3. Order Line Items Table
                    doc.Add(new Paragraph("PURCHASE ORDER LINE ITEMS").SetFontSize(9.5f).SetBold().SetFontColor(darkSlate));

                    var itemsTable = new Table(UnitValue.CreatePercentArray(new float[] { 8, 42, 16, 16, 18 })).UseAllAvailableWidth();
                    itemsTable.SetMarginTop(4);

                    // Table Header
                    string[] headers = { "#", "Material Item & SKU", "Quantity", "Unit Price", "Total Price" };
                    for (int i = 0; i < headers.Length; i++)
                    {
                        var cell = new Cell().Add(new Paragraph(headers[i]).SetFontSize(8.5f).SetBold().SetFontColor(ColorConstants.WHITE));
                        cell.SetBackgroundColor(darkSlate);
                        cell.SetPadding(6);
                        if (i >= 2) cell.SetTextAlignment(TextAlignment.RIGHT);
                        itemsTable.AddHeaderCell(cell);
                    }

                    int itemIndex = 1;
                    if (po.OrderLines != null && po.OrderLines.Any())
                    {
                        foreach (var line in po.OrderLines)
                        {
                            var rowBg = (itemIndex % 2 == 0) ? bgLight : ColorConstants.WHITE;

                            // Col 1: #
                            itemsTable.AddCell(new Cell().Add(new Paragraph(itemIndex.ToString()).SetFontSize(8.5f))
                                .SetBackgroundColor(rowBg).SetPadding(6).SetBorderBottom(new SolidBorder(borderLight, 0.5f)));

                            // Col 2: Material & SKU
                            var descCell = new Cell().SetBackgroundColor(rowBg).SetPadding(6).SetBorderBottom(new SolidBorder(borderLight, 0.5f));
                            var matName = line.RawMaterial?.Name ?? line.Description ?? $"Industrial Material Item #{line.RawMaterialId}";
                            descCell.Add(new Paragraph(matName).SetFontSize(8.5f).SetBold().SetFontColor(darkSlate));
                            var sku = line.RawMaterial?.SkuCode ?? $"RM-{line.RawMaterialId}";
                            descCell.Add(new Paragraph($"SKU: {sku}").SetFontSize(7.5f).SetFontColor(grayText));
                            itemsTable.AddCell(descCell);

                            // Col 3: Quantity
                            var unit = line.RawMaterial?.UnitOfMeasure ?? "units";
                            itemsTable.AddCell(new Cell().Add(new Paragraph($"{line.Quantity:N2} {unit}").SetFontSize(8.5f))
                                .SetBackgroundColor(rowBg).SetPadding(6).SetTextAlignment(TextAlignment.RIGHT).SetBorderBottom(new SolidBorder(borderLight, 0.5f)));

                            // Col 4: Unit Price
                            itemsTable.AddCell(new Cell().Add(new Paragraph($"${line.UnitPrice:N2}").SetFontSize(8.5f))
                                .SetBackgroundColor(rowBg).SetPadding(6).SetTextAlignment(TextAlignment.RIGHT).SetBorderBottom(new SolidBorder(borderLight, 0.5f)));

                            // Col 5: Total Price
                            var lineTotal = line.TotalPrice > 0 ? line.TotalPrice : line.Quantity * line.UnitPrice;
                            itemsTable.AddCell(new Cell().Add(new Paragraph($"${lineTotal:N2}").SetFontSize(8.5f).SetBold().SetFontColor(darkSlate))
                                .SetBackgroundColor(rowBg).SetPadding(6).SetTextAlignment(TextAlignment.RIGHT).SetBorderBottom(new SolidBorder(borderLight, 0.5f)));

                            itemIndex++;
                        }
                    }
                    else
                    {
                        var emptyCell = new Cell(1, 5).Add(new Paragraph("Standard inventory procurement lot.").SetFontSize(8.5f).SetItalic());
                        emptyCell.SetPadding(8).SetTextAlignment(TextAlignment.CENTER);
                        itemsTable.AddCell(emptyCell);
                    }

                    doc.Add(itemsTable);
                    doc.Add(new Paragraph(" ").SetFontSize(6));

                    // 4. Financial Summary Block
                    var summaryTable = new Table(UnitValue.CreatePercentArray(new float[] { 55, 45 })).UseAllAvailableWidth();
                    summaryTable.SetBorder(Border.NO_BORDER);

                    var notesCell = new Cell().SetBorder(Border.NO_BORDER).SetPadding(6);
                    if (!string.IsNullOrWhiteSpace(po.Notes))
                    {
                        notesCell.Add(new Paragraph("ORDER INSTRUCTIONS:").SetFontSize(8).SetBold().SetFontColor(grayText));
                        notesCell.Add(new Paragraph(po.Notes).SetFontSize(8.5f).SetItalic().SetFontColor(darkSlate));
                    }
                    notesCell.Add(new Paragraph("Authorized by Supply Chain Division. Dispatched via Automated Inventory Coordinator.")
                        .SetFontSize(7.5f).SetFontColor(grayText).SetMarginTop(4));
                    summaryTable.AddCell(notesCell);

                    var totalCell = new Cell().SetBorder(new SolidBorder(brandBlue, 1.5f)).SetBackgroundColor(bgLight).SetPadding(8).SetTextAlignment(TextAlignment.RIGHT);
                    totalCell.Add(new Paragraph("TOTAL COMMITTED AMOUNT").SetFontSize(7.5f).SetBold().SetFontColor(grayText));
                    totalCell.Add(new Paragraph($"${po.TotalCost:N2} {(string.IsNullOrWhiteSpace(po.Currency) ? "USD" : po.Currency.ToUpperInvariant())}")
                        .SetFontSize(15).SetBold().SetFontColor(brandBlue));
                    summaryTable.AddCell(totalCell);

                    doc.Add(summaryTable);
                    doc.Add(new Paragraph(" ").SetFontSize(10));

                    // 5. Legal Terms & Compliance Footer
                    var footer = new Paragraph("AMIC Procurement Notice: Deliveries must strictly adhere to contractual SLA timelines and quality standards. Contact logistics@amic-manufacturing.internal for gate receiving coordinates.")
                        .SetFontSize(7).SetFontColor(grayText).SetTextAlignment(TextAlignment.CENTER);
                    doc.Add(footer);

                    // CRITICAL: Must close Document so PDF trailer and xref are flushed to MemoryStream
                    doc.Close();
                }

                pdfBytes = ms.ToArray();
            }

            return pdfBytes;
        }

        // ── Audit Recording ───────────────────────────────────────────────────────

        private async Task RecordAuditAsync(int poId, string action, Guid? userId, string? notes)
        {
            string? userName = null;
            if (userId.HasValue)
            {
                var user = await _context.Users.FindAsync(userId.Value);
                userName = user?.FullName ?? user?.Email;
            }

            var audit = new PurchaseOrderApproval
            {
                PurchaseOrderId = poId,
                Action = action,
                UserId = userId,
                UserName = userName,
                Notes = notes,
                Timestamp = DateTime.UtcNow
            };

            _context.PurchaseOrderApprovals.Add(audit);
            await _context.SaveChangesAsync();
        }

        // ── Transaction Helper ────────────────────────────────────────────────────

        private async Task<Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction?> BeginTransactionIfSupportedAsync()
        {
            if (_context.Database.IsRelational())
            {
                return await _context.Database.BeginTransactionAsync();
            }
            return null;
        }

        // ── Helpers ───────────────────────────────────────────────────────────────

        private async Task<PurchaseOrder> LoadPoAsync(int id)
        {
            return await _context.PurchaseOrders
                .Include(p => p.OrderLines)
                .FirstOrDefaultAsync(p => p.Id == id)
                ?? throw new KeyNotFoundException($"Purchase Order {id} not found.");
        }

        private async Task<string> GeneratePoNumberAsync()
        {
            var prefix = _configuration["PurchaseOrderSettings:PoNumberPrefix"] ?? "PO";
            var year = DateTime.UtcNow.Year;
            var count = await _context.PurchaseOrders.CountAsync(p => p.CreatedAt.Year == year);
            return $"{prefix}-{year}-{(count + 1):D4}";
        }

        private static PurchaseOrderResponseDto MapToDto(PurchaseOrder po) => new()
        {
            Id = po.Id,
            PoNumber = po.PoNumber,
            SupplierId = po.SupplierId,
            SupplierName = po.Supplier?.Name ?? string.Empty,
            Status = po.Status.ToString(),
            Currency = po.Currency,
            TotalCost = po.TotalCost,
            BudgetLimit = po.BudgetLimit,
            ApprovalThreshold = po.ApprovalThreshold,
            RequiresApproval = po.RequiresApproval,
            Notes = po.Notes,
            RejectionReason = po.RejectionReason,
            CreatedById = po.CreatedById,
            CreatedByName = po.CreatedBy?.FullName,
            ApprovedByName = po.ApprovedBy?.FullName,
            ApprovedAt = po.ApprovedAt,
            StripePaymentIntentId = po.StripePaymentIntentId,
            StripePaymentStatus = po.StripePaymentStatus,
            BankSlipUrl = po.BankSlipUrl,
            BankReferenceNumber = po.BankReferenceNumber,
            BankSlipStatus = po.BankSlipStatus,
            BankSlipUploadedAt = po.BankSlipUploadedAt,
            TrackingStatus = po.TrackingStatus ?? po.Status.ToString(),
            TrackingNumber = po.TrackingNumber,
            ExpectedDeliveryDate = po.ExpectedDeliveryDate,
            EmailStatus = po.EmailStatus,
            EmailSentAt = po.EmailSentAt,
            OrderLines = po.OrderLines.Select(ol => new OrderLineResponseDto
            {
                Id = ol.Id,
                RawMaterialId = ol.RawMaterialId,
                RawMaterialName = ol.RawMaterial?.Name ?? string.Empty,
                RawMaterialSku = ol.RawMaterial?.SkuCode ?? string.Empty,
                Description = ol.Description,
                Quantity = ol.Quantity,
                UnitPrice = ol.UnitPrice,
                TotalPrice = ol.TotalPrice
            }).ToList(),
            Approvals = po.Approvals.OrderBy(a => a.Timestamp).Select(a => new PurchaseOrderApprovalDto
            {
                Id = a.Id,
                Action = a.Action,
                UserId = a.UserId,
                UserName = a.UserName,
                Notes = a.Notes,
                Timestamp = a.Timestamp
            }).ToList(),
            Transactions = po.Transactions.OrderBy(t => t.Timestamp).Select(t => new PaymentTransactionDto
            {
                Id = t.Id,
                TransactionId = t.TransactionId,
                Amount = t.Amount,
                Currency = t.Currency,
                PaymentStatus = t.PaymentStatus,
                FailureReason = t.FailureReason,
                Timestamp = t.Timestamp
            }).ToList(),
            CreatedAt = po.CreatedAt,
            UpdatedAt = po.UpdatedAt
        };

        public async Task<PurchaseOrderResponseDto> UploadBankSlipAsync(
            int id, Microsoft.AspNetCore.Http.IFormFile? file, string referenceNumber, string? notes = null, Guid? userId = null)
        {
            if (string.IsNullOrWhiteSpace(referenceNumber))
                throw new ArgumentException("Bank transaction reference number is required.");

            var po = await LoadPoAsync(id);

            // Create uploads directory in wwwroot
            var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "slips");
            Directory.CreateDirectory(uploadsDir);

            string uniqueFileName;
            if (file != null && file.Length > 0)
            {
                if (file.Length > 10 * 1024 * 1024)
                    throw new ArgumentException("Bank slip file size cannot exceed 10 MB.");

                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                var allowedExtensions = new[] { ".pdf", ".png", ".jpg", ".jpeg" };
                if (!allowedExtensions.Contains(ext))
                    throw new ArgumentException("Invalid file format. Only PDF, PNG, and JPG/JPEG files are accepted.");

                uniqueFileName = $"slip_{po.PoNumber}_{Guid.NewGuid():N}{ext}";
                var filePath = Path.Combine(uploadsDir, uniqueFileName);

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }
            }
            else
            {
                uniqueFileName = $"slip_{po.PoNumber}_{Guid.NewGuid():N}.html";
                var filePath = Path.Combine(uploadsDir, uniqueFileName);
                var content = $@"<!DOCTYPE html><html><head><title>Bank Transfer Receipt - {po.PoNumber}</title>
<style>body{{font-family:sans-serif;padding:30px;background:#0f172a;color:#f8fafc}} .box{{background:#1e293b;padding:24px;border-radius:12px;border:1px solid #334155;max-width:500px;margin:auto;}} h2{{color:#38bdf8;margin-top:0;}} .row{{display:flex;justify-content:space-between;margin:12px 0;border-bottom:1px solid #334155;padding-bottom:8px;}} .badge{{background:#10b981;color:#fff;padding:4px 10px;border-radius:6px;font-size:12px;font-weight:bold;}}</style>
</head><body><div class='box'><h2>Bank Transfer Verification</h2>
<div class='row'><span>Purchase Order</span><strong>{po.PoNumber}</strong></div>
<div class='row'><span>Reference Number</span><strong>{referenceNumber}</strong></div>
<div class='row'><span>Amount Paid</span><strong>${po.TotalCost:N2} {po.Currency}</strong></div>
<div class='row'><span>Status</span><span class='badge'>VERIFIED</span></div>
<div class='row'><span>Date</span><span>{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC</span></div>
<p style='color:#94a3b8;font-size:12px;margin-top:16px;'>{notes ?? "Electronic bank transfer confirmation."}</p>
</div></body></html>";
                await File.WriteAllTextAsync(filePath, content);
            }

            po.BankSlipUrl = $"/uploads/slips/{uniqueFileName}";
            po.BankReferenceNumber = referenceNumber.Trim();
            po.BankSlipStatus = "VERIFIED";
            po.BankSlipUploadedAt = DateTime.UtcNow;
            po.TrackingStatus = "Paid";
            po.UpdatedAt = DateTime.UtcNow;

            // Transition status to Paid if already Approved
            if (po.Status == PurchaseOrderStatus.Approved || po.Status == PurchaseOrderStatus.Payment)
            {
                TransitionStatus(po, PurchaseOrderStatus.Paid);
            }

            // Record transaction
            var txRecord = new PaymentTransaction
            {
                PurchaseOrderId = po.Id,
                TransactionId = $"SLIP-{referenceNumber.Trim()}",
                Amount = po.TotalCost,
                Currency = po.Currency.ToLowerInvariant(),
                PaymentStatus = "succeeded (bank slip)",
                FailureReason = null,
                Timestamp = DateTime.UtcNow
            };
            _context.PaymentTransactions.Add(txRecord);

            await RecordAuditAsync(po.Id, "bank slip uploaded", userId, $"Bank slip verified with ref {referenceNumber}.");

            await _context.SaveChangesAsync();

            // After payment settlement, auto-dispatch email with receipt to supplier
            await SendPoEmailAsync(po, userId, forceDispatch: true);

            return (await GetByIdAsync(po.Id))!;
        }

        public async Task<PurchaseOrderTrackingDto> GetTrackingAsync(int id)
        {
            var po = await _context.PurchaseOrders
                .Include(p => p.Supplier)
                .Include(p => p.OrderLines)
                .FirstOrDefaultAsync(p => p.Id == id)
                ?? throw new KeyNotFoundException($"Purchase Order {id} not found.");

            var trackingDto = new PurchaseOrderTrackingDto
            {
                PurchaseOrderId = po.Id,
                PoNumber = po.PoNumber,
                SupplierId = po.SupplierId,
                SupplierName = po.Supplier?.Name ?? "Supplier",
                Status = po.Status.ToString(),
                TrackingStatus = po.TrackingStatus ?? po.Status.ToString(),
                TrackingNumber = po.TrackingNumber ?? $"TRK-{po.PoNumber}",
                TotalCost = po.TotalCost,
                Currency = po.Currency,
                PaymentMethod = !string.IsNullOrWhiteSpace(po.BankSlipUrl) ? "Bank Transfer (Slip)" : (!string.IsNullOrWhiteSpace(po.StripePaymentIntentId) ? "Stripe Sandbox" : "Pending"),
                PaymentStatus = po.StripePaymentStatus ?? po.BankSlipStatus ?? (po.Status == PurchaseOrderStatus.Paid || po.Status == PurchaseOrderStatus.Sent ? "Paid" : "Pending"),
                PaymentReference = po.BankReferenceNumber ?? po.StripePaymentIntentId,
                BankSlipUrl = po.BankSlipUrl,
                EmailStatus = po.EmailStatus,
                EmailSentAt = po.EmailSentAt,
                CreatedAt = po.CreatedAt,
                ApprovedAt = po.ApprovedAt,
                ExpectedDeliveryDate = po.ExpectedDeliveryDate ?? po.CreatedAt.AddDays(po.Supplier?.LeadTimeDays > 0 ? po.Supplier.LeadTimeDays : 7),
                ActualDeliveryDate = po.ActualDeliveryDate
            };

            bool isPendingApproval = po.Status >= PurchaseOrderStatus.PendingApproval && po.Status != PurchaseOrderStatus.Draft;
            bool isApproved = po.Status >= PurchaseOrderStatus.Approved && po.Status != PurchaseOrderStatus.PendingApproval && po.Status != PurchaseOrderStatus.Draft && po.Status != PurchaseOrderStatus.Rejected;
            bool isPaid = po.Status == PurchaseOrderStatus.Paid || po.Status == PurchaseOrderStatus.Sent || po.Status == PurchaseOrderStatus.Delivered || po.Status == PurchaseOrderStatus.Completed || !string.IsNullOrWhiteSpace(po.BankSlipUrl) || po.StripePaymentStatus == "succeeded";
            bool isNotified = po.EmailStatus == "Sent" || po.EmailStatus == "Sent (Sandbox Dispatch)";
            bool isSent = po.Status == PurchaseOrderStatus.Sent || po.Status == PurchaseOrderStatus.Delivered || po.Status == PurchaseOrderStatus.Completed;
            bool isInTransit = (isSent || po.Status == PurchaseOrderStatus.InTransit) && po.Status != PurchaseOrderStatus.Delivered && po.Status != PurchaseOrderStatus.Completed;
            bool isDelivered = po.Status == PurchaseOrderStatus.Delivered || po.Status == PurchaseOrderStatus.Completed;
            bool isCompleted = po.Status == PurchaseOrderStatus.Completed;

            trackingDto.Timeline = new List<TrackingTimelineStepDto>
            {
                new() { StepKey = "draft", Title = "Draft Created", Description = "PO created in draft status", IsCompleted = true, IsCurrent = po.Status == PurchaseOrderStatus.Draft, Timestamp = po.CreatedAt },
                new() { StepKey = "pending_approval", Title = "Pending Approval", Description = "Submitted for Supply Chain Manager approval", IsCompleted = isPendingApproval, IsCurrent = po.Status == PurchaseOrderStatus.PendingApproval, Timestamp = po.CreatedAt },
                new() { StepKey = "approved", Title = "Manager Approved", Description = "Supply Chain Manager approved the purchase order", IsCompleted = isApproved, IsCurrent = po.Status == PurchaseOrderStatus.Approved, Timestamp = po.ApprovedAt },
                new() { StepKey = "payment_pending", Title = "Payment Authorization", Description = "Stripe card settlement or bank slip submission", IsCompleted = isPaid, IsCurrent = isApproved && !isPaid, Timestamp = po.ApprovedAt },
                new() { StepKey = "paid", Title = "Payment Settled", Description = "Payment confirmed via Stripe or verified bank slip", IsCompleted = isPaid, IsCurrent = isPaid && !isNotified, Timestamp = po.BankSlipUploadedAt ?? po.ApprovedAt },
                new() { StepKey = "notified", Title = "Supplier Notified", Description = "PO PDF & payment confirmation dispatched to supplier", IsCompleted = isNotified, IsCurrent = isNotified && !isSent, Timestamp = po.EmailSentAt },
                new() { StepKey = "ordered", Title = "Order Dispatched", Description = "Official order confirmed and placed with vendor", IsCompleted = isSent, IsCurrent = isSent && !isDelivered, Timestamp = po.EmailSentAt ?? po.UpdatedAt },
                new() { StepKey = "in_transit", Title = "In Transit", Description = $"Shipment in transit via tracking {trackingDto.TrackingNumber}", IsCompleted = isDelivered || isInTransit, IsCurrent = isInTransit, Timestamp = po.ExpectedDeliveryDate },
                new() { StepKey = "delivered", Title = "Delivered & Inspected", Description = "Raw materials received on factory floor for QA inspection", IsCompleted = isDelivered, IsCurrent = isDelivered && !isCompleted, Timestamp = po.ActualDeliveryDate },
                new() { StepKey = "completed", Title = "Order Completed", Description = "Procurement lifecycle fulfilled and closed", IsCompleted = isCompleted, IsCurrent = isCompleted, Timestamp = po.ActualDeliveryDate }
            };

            return trackingDto;
        }
    }
}
