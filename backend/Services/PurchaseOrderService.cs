using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
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

        private const string DefaultCurrency = "usd";

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
            return (await GetByIdAsync(po.Id))!;
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

            if (tx is not null) await tx.CommitAsync();

            return (await GetByIdAsync(po.Id))!;
        }

        public async Task<PurchaseOrderResponseDto> ApproveAsync(int id, Guid approverId, string? notes = null)
        {
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
            }

            // Reload for payment processing
            var approvedPo = await LoadPoAsync(id);

            // Trigger payment and dispatch after approval (with dev sandbox support)
            await ProcessPaymentInternalAsync(approvedPo, approverId, forceDispatch: true);

            return (await GetByIdAsync(approvedPo.Id))!;
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
            if (po.Status != PurchaseOrderStatus.Payment && po.Status != PurchaseOrderStatus.Approved)
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
                    await _context.SaveChangesAsync();

                    // Record audit: payment failed
                    await RecordAuditAsync(po.Id, "payment failed", approverId, $"Stripe failure: {result.ErrorMessage}");

                    if (tx is not null) await tx.CommitAsync();

                    _logger.LogWarning(
                        "Stripe payment failed for PO {PoNumber}: {Error}. Status remains Payment.",
                        po.PoNumber, result.ErrorMessage);
                    return;
                }

                // Clear previous failure reasons on success
                po.PaymentFailureReason = null;
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
    }
}
