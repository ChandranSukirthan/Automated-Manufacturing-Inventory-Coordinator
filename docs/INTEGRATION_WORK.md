# Integration repair

Authorized scope: A–J from the integration review. Preserve existing edits and data.

Implementation order:
1. Workflow API contract and authentication propagation.
2. Persist physical roll batch identity and map QA to the exact physical roll/material.
3. Reconcile stock changes and record inventory movements.
4. Explicit idempotent goods receipt, including partial delivery.
5. Exact quarantine checks and QA release/revalidation.
6. Separate maintenance and procurement orchestration.
7. Enforce domain approval ownership.
8. Persist/resume/retry workflow state, isolate failures and remove operational guesses.
9. Use actual workflow records in web/mobile monitors.
10. Check CRUD contracts, permissions and user-facing errors.

Baseline: 40 backend tests pass before changes. Database migrations will be additive;
historical records that cannot be mapped exactly must remain for manual reconciliation.
No email, payment or live inventory mutations are part of verification.
