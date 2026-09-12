using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using iText.Kernel.Pdf;
using iText.Layout;
using iText.Layout.Element;
using ManufacturingCoordinator.Data;
using ManufacturingCoordinator.DTOs.PurchaseOrders;
using ManufacturingCoordinator.Enums;
using ManufacturingCoordinator.Models.PurchaseOrders;
using ManufacturingCoordinator.Api.Interfaces;

namespace ManufacturingCoordinator.Services.PurchaseOrders
{
    public class PurchaseOrderService : IPurchaseOrderService
    {
        private readonly ApplicationDbContext _context;
        private readonly IStripeService _stripeService;
        private readonly IEmailService _emailService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<PurchaseOrderService> _logger;

        private const string Currency = "usd";

        public PurchaseOrderService(
            ApplicationDbContext context,
            IStripeService stripeService,
            IEmailService emailService,
            IConfiguration configuration,
            ILogger<PurchaseOrderService> logger)
        {
            _context = context;
            _stripeService = stripeService;
            _emailService = emailService;
            _configuration = configuration;
            _logger = logger;
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
                .Include(p => p.ApprovedBy)
                .Include(p => p.OrderLines)
                    .ThenInclude(ol => ol.RawMaterial)
                .FirstOrDefaultAsync(p => p.Id == id);

            return po is null ? null : MapToDto(po);
        }

        // ── Create ────────────────────────────────────────────────────────────────

        public async Task<PurchaseOrderResponseDto> CreateAsync(CreatePurchaseOrderDto dto)
        {
            // Validate supplier exists and is active
            var supplier = await _context.Suppliers.FindAsync(dto.SupplierId)
                ?? throw new KeyNotFoundException($"Supplier {dto.SupplierId} not found.");

            if (!supplier.IsActive)
                throw new InvalidOperationException("Cannot create a PO for an inactive supplier.");

            var approvalThreshold = _configuration.GetValue<decimal>(
                "PurchaseOrderSettings:ApprovalThresholdAmount", 5000m);

            var po = new PurchaseOrder
            {
                PoNumber = await GeneratePoNumberAsync(),
                SupplierId = dto.SupplierId,
                BudgetLimit = dto.BudgetLimit,
                Notes = dto.Notes,
                Status = PurchaseOrderStatus.Draft,
                ApprovalThreshold = approvalThreshold,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            // Build order lines
            foreach (var lineDto in dto.Lines)
            {
                var line = new OrderLine
                {
                    RawMaterialId = lineDto.RawMaterialId,
                    Description = lineDto.Description,
                    Quantity = lineDto.Quantity,
                    UnitPrice = lineDto.UnitPrice,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };
                line.TotalPrice = CalculateLineCost(line);
                po.OrderLines.Add(line);
            }

            // Business rules
            po.TotalCost = CalculateTotalCost(po);
            ValidateBudget(po);
            CheckApprovalThreshold(po);

            _context.PurchaseOrders.Add(po);
            await _context.SaveChangesAsync();

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

            var supplier = await _context.Suppliers.FindAsync(dto.SupplierId)
                ?? throw new KeyNotFoundException($"Supplier {dto.SupplierId} not found.");
            if (!supplier.IsActive)
                throw new InvalidOperationException("Cannot assign an inactive supplier.");

            po.SupplierId = dto.SupplierId;
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
                    RawMaterialId = lineDto.RawMaterialId,
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
            CheckApprovalThreshold(po);

            await _context.SaveChangesAsync();
            return (await GetByIdAsync(po.Id))!;
        }

        // ── Approval Workflow ─────────────────────────────────────────────────────

        public async Task<PurchaseOrderResponseDto> SubmitForApprovalAsync(int id)
        {
            var po = await LoadPoAsync(id);
            TransitionStatus(po, PurchaseOrderStatus.PendingApproval);
            po.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return (await GetByIdAsync(po.Id))!;
        }

        public async Task<PurchaseOrderResponseDto> ApproveAsync(int id, int approverId)
        {
            var po = await LoadPoAsync(id);
            TransitionStatus(po, PurchaseOrderStatus.Approved);

            po.ApprovedById = approverId;
            po.ApprovedAt = DateTime.UtcNow;
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            // Trigger payment after approval
            await ProcessPaymentAsync(po);

            return (await GetByIdAsync(po.Id))!;
        }

        public async Task<PurchaseOrderResponseDto> RejectAsync(int id, int approverId, string? reason)
        {
            var po = await LoadPoAsync(id);
            TransitionStatus(po, PurchaseOrderStatus.Rejected);

            po.ApprovedById = approverId;
            po.ApprovedAt = DateTime.UtcNow;
            po.RejectionReason = reason;
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return (await GetByIdAsync(po.Id))!;
        }

        public async Task<PurchaseOrderResponseDto> RequestRevisionAsync(int id, int approverId, string? reason)
        {
            var po = await LoadPoAsync(id);
            TransitionStatus(po, PurchaseOrderStatus.RevisionRequested);

            po.ApprovedById = approverId;
            po.RejectionReason = reason;
            po.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            // Revert to Draft so requester can edit
            TransitionStatus(po, PurchaseOrderStatus.Draft);
            po.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return (await GetByIdAsync(po.Id))!;
        }

        // ── Business Rules ────────────────────────────────────────────────────────

        /// <summary>
        /// calculateTotalCost(): Sums all OrderLine.Quantity × UnitPrice.
        /// Example: Qty=2000 KG × $4.50 = $9,000
        /// </summary>
        private static decimal CalculateTotalCost(PurchaseOrder po)
        {
            return po.OrderLines.Sum(line => line.TotalPrice);
        }

        private static decimal CalculateLineCost(OrderLine line)
        {
            return Math.Round(line.Quantity * line.UnitPrice, 2);
        }

        /// <summary>
        /// validateBudget(): Throws if TotalCost exceeds BudgetLimit.
        /// </summary>
        private static void ValidateBudget(PurchaseOrder po)
        {
            if (po.TotalCost > po.BudgetLimit)
                throw new InvalidOperationException(
                    $"Total cost ({po.TotalCost:C}) exceeds budget limit ({po.BudgetLimit:C}). " +
                    "Reduce quantities or increase the budget limit.");
        }

        /// <summary>
        /// checkApprovalThreshold(): Sets RequiresApproval = true when TotalCost > ApprovalThreshold.
        /// Default threshold is $5,000.
        /// </summary>
        private static void CheckApprovalThreshold(PurchaseOrder po)
        {
            po.RequiresApproval = po.TotalCost > po.ApprovalThreshold;
        }

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
        /// Triggered after Approve. Calls Stripe sandbox, handles failure safely.
        /// Does NOT mark as Sent if payment fails.
        /// </summary>
        private async Task ProcessPaymentAsync(PurchaseOrder po)
        {
            TransitionStatus(po, PurchaseOrderStatus.Payment);
            po.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            var description = $"Purchase Order {po.PoNumber}";
            var result = await _stripeService.CreatePaymentIntentAsync(po.TotalCost, Currency, description);

            po.StripePaymentIntentId = result.PaymentIntentId;
            po.StripePaymentStatus = result.Status;
            po.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            if (!result.Success)
            {
                _logger.LogWarning(
                    "Stripe payment failed for PO {PoNumber}: {Error}. Status remains Payment.",
                    po.PoNumber, result.ErrorMessage);
                // Do NOT advance to Sent — stays in Payment status
                return;
            }

            // Payment succeeded — generate PDF and email
            await SendPoEmailAsync(po);
        }

        /// <summary>
        /// Generates PO PDF using iText7, sends via SendGrid/EmailService.
        /// Does NOT mark as Sent if email fails.
        /// </summary>
        private async Task SendPoEmailAsync(PurchaseOrder po)
        {
            // Reload with supplier for email
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

                // Only advance to Sent after successful email
                TransitionStatus(poFull, PurchaseOrderStatus.Sent);
                poFull.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                _logger.LogInformation("PO {PoNumber} sent to {Email}", poFull.PoNumber, poFull.Supplier.ContactEmail);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send PO email for {PoNumber}. Status stays at Payment.", poFull.PoNumber);
                // Do NOT advance to Sent — stays in Payment status
            }
        }

        // ── PDF Generation ────────────────────────────────────────────────────────

        private static byte[] GeneratePoPdf(PurchaseOrder po)
        {
            using var ms = new MemoryStream();
            using var writer = new PdfWriter(ms);
            using var pdf = new PdfDocument(writer);
            using var doc = new Document(pdf);

            doc.Add(new Paragraph($"PURCHASE ORDER — {po.PoNumber}")
                .SetFontSize(18).SetBold());
            doc.Add(new Paragraph($"Supplier: {po.Supplier.Name}"));
            doc.Add(new Paragraph($"Status: {po.Status}"));
            doc.Add(new Paragraph($"Date: {po.CreatedAt:yyyy-MM-dd}"));
            doc.Add(new Paragraph(" "));
            doc.Add(new Paragraph("ORDER LINES:").SetBold());

            var table = new Table(5).UseAllAvailableWidth();
            foreach (var header in new[] { "Raw Material", "SKU", "Qty", "Unit Price", "Total" })
                table.AddHeaderCell(header);

            foreach (var line in po.OrderLines)
            {
                table.AddCell(line.RawMaterial?.Name ?? "—");
                table.AddCell(line.RawMaterial?.SkuCode ?? "—");
                table.AddCell(line.Quantity.ToString("F3"));
                table.AddCell($"${line.UnitPrice:F2}");
                table.AddCell($"${line.TotalPrice:F2}");
            }

            doc.Add(table);
            doc.Add(new Paragraph(" "));
            doc.Add(new Paragraph($"TOTAL COST: ${po.TotalCost:F2}").SetBold().SetFontSize(14));

            if (!string.IsNullOrEmpty(po.Notes))
                doc.Add(new Paragraph($"Notes: {po.Notes}"));

            return ms.ToArray();
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
            TotalCost = po.TotalCost,
            BudgetLimit = po.BudgetLimit,
            ApprovalThreshold = po.ApprovalThreshold,
            RequiresApproval = po.RequiresApproval,
            Notes = po.Notes,
            RejectionReason = po.RejectionReason,
            ApprovedByName = po.ApprovedBy?.FullName,
            ApprovedAt = po.ApprovedAt,
            StripePaymentIntentId = po.StripePaymentIntentId,
            StripePaymentStatus = po.StripePaymentStatus,
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
            CreatedAt = po.CreatedAt,
            UpdatedAt = po.UpdatedAt
        };
    }
}
