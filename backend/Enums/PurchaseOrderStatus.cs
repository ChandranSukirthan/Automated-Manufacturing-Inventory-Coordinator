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
        Sent
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
                    PurchaseOrderStatus.Payment
                },
                [PurchaseOrderStatus.Payment] = new HashSet<PurchaseOrderStatus>
                {
                    PurchaseOrderStatus.Sent
                },
                // Terminal states — no further transitions
                [PurchaseOrderStatus.Rejected] = new HashSet<PurchaseOrderStatus>(),
                [PurchaseOrderStatus.Sent] = new HashSet<PurchaseOrderStatus>()
            };

        public static bool IsTransitionAllowed(PurchaseOrderStatus from, PurchaseOrderStatus to)
        {
            return AllowedTransitions.TryGetValue(from, out var allowed) && allowed.Contains(to);
        }
    }
}

