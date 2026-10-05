using System.Collections.Generic;

namespace ManufacturingCoordinator.Enums
{
    public enum PurchaseOrderStatus
    {
        Draft,
        PendingApproval,
        Approved,
        Rejected,
        RevisionRequested,
        Payment,
        Sent,
        PaymentPending,
        Paid,
        SupplierNotified,
        InTransit,
        Delivered,
        Completed,
        PaymentFailed
    }

    public static class PurchaseOrderStatusTransitions
    {
        /// <summary>
        /// Defines which target statuses are valid from each source status.
        /// </summary>
        public static readonly Dictionary<PurchaseOrderStatus, HashSet<PurchaseOrderStatus>> AllowedTransitions =
            new()
            {
                [PurchaseOrderStatus.Draft] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.PendingApproval
                },
                [PurchaseOrderStatus.PendingApproval] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Approved,
                    PurchaseOrderStatus.Rejected,
                    PurchaseOrderStatus.RevisionRequested
                },
                [PurchaseOrderStatus.RevisionRequested] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Draft
                },
                [PurchaseOrderStatus.Approved] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Payment,
                    PurchaseOrderStatus.PaymentPending,
                    PurchaseOrderStatus.Paid
                },
                [PurchaseOrderStatus.Payment] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Paid,
                    PurchaseOrderStatus.Sent,
                    PurchaseOrderStatus.PaymentFailed
                },
                [PurchaseOrderStatus.PaymentPending] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Paid,
                    PurchaseOrderStatus.PaymentFailed
                },
                [PurchaseOrderStatus.Paid] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.SupplierNotified,
                    PurchaseOrderStatus.Sent
                },
                [PurchaseOrderStatus.SupplierNotified] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Sent,
                    PurchaseOrderStatus.InTransit
                },
                [PurchaseOrderStatus.Sent] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.InTransit,
                    PurchaseOrderStatus.Delivered,
                    PurchaseOrderStatus.Completed
                },
                [PurchaseOrderStatus.InTransit] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Delivered,
                    PurchaseOrderStatus.Completed
                },
                [PurchaseOrderStatus.Delivered] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Completed
                },
                [PurchaseOrderStatus.PaymentFailed] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Payment,
                    PurchaseOrderStatus.PaymentPending,
                    PurchaseOrderStatus.Draft
                },
                // Terminal states
                [PurchaseOrderStatus.Rejected] = new HashSet<PurchaseOrderStatus>(),
                [PurchaseOrderStatus.Completed] = new HashSet<PurchaseOrderStatus>()
            };

        public static bool IsTransitionAllowed(PurchaseOrderStatus from, PurchaseOrderStatus to)
        {
            return AllowedTransitions.TryGetValue(from, out var allowed) && allowed.Contains(to);
        }
    }
}

