# Integration repair audit — 2026-10-04

## Recovery and branch protection

Initial checkout: clean `Merge` at `23d17b6`. The interrupted repair existed on `origin/Merge` at `94678823d497000980cc1b48818523e6d171cc8e`. Only `Merge` was fast-forwarded to recover it. Follow-up repairs remain uncommitted; nothing was pushed. No additional worktree was needed. No applicable AGENTS.md was found in inspected project/parent paths.

`main` was never checked out or updated. Its before/after hash is `91843c86da1fa5bc83f761dc862e092c41b8fb89`.

## A–J implementation audit

“Implemented” describes code and automated evidence, not deployment or manual verification against a production database.

| Scope | Actual state and evidence |
| --- | --- |
| A: contracts/auth | Implemented: structured workflow responses, authenticated forwarding, signed actor attribution, role/type checks, fresh bearer context on retry. Authentication, contract, retry and queued-request identity tests pass. |
| B: material/SKU/roll/batch | Implemented with historical reconciliation: batch required in React and both Flutter roll forms; material identity immutable; incompatible receipt packaging rejected. Missing QA physical links, batches and catalogue mappings are reported rather than guessed. |
| C: stock CRUD/movements | Implemented: stock changes record persisted movements, synthetic history removed, and stock/history deletion is guarded with conflict responses. HTTP role tests cover roll and stock CRUD with AI offline. Isolated PostgreSQL concurrency tests prove separate receipts do not lose stock. |
| D: goods receipt | Implemented: approval/payment/dispatch do not receive stock; explicit partial receipts use stable keys, serializable transactions and unique database identities. Isolated PostgreSQL tests cover concurrent duplicate delivery, retry, distinct partial deliveries and over-delivery rejection. |
| E: quarantine/revalidation | Implemented: exact physical material/batch scope; legacy SKU not inferred from batch; QA owns release. Tests cover other-batch isolation, wrong-batch refusal, release once, remaining batch holds and new defects invalidating old QA resolutions. |
| F: maintenance | Implemented: separate routing, exact machine identity, no purchasing or procurement order creation. Corrected malformed GUID regex. Routing/exact-machine/repeated-approval tests pass. |
| G: approvals | Implemented: SCM procurement, QA quality/quarantine, ITAdmin maintenance. Signed-token HTTP tests verify role access and cross-role denial with the AI client offline. |
| H: workflow recovery | Implemented: SQLite state, interrupted recovery, retry preserving inputs, failure isolation, existing-draft reuse and PO/request uniqueness. Per-workflow OS locks coordinate separate AI worker processes; startup skips workflows locked by another worker. Real-node tests verify every agent receives upstream state/tool results and revisions replace stale drafts without changing the original requirement. |
| I: workflow UI | Implemented: real workflow type/stages/errors/outcome/retry, receipt/quote forms, evidence pending verification, canonical roll identifiers, and real service health. Removed local success/payment/supplier/inventory fallbacks. React lint/build/tests and Flutter analysis/tests pass. No browser/device walkthrough was performed. |
| J: wider CRUD audit | Automated role CRUD is covered for Floor Worker inventory/rolls, QA defects/quarantine, SCM suppliers/quotes/POs/order lines, and IT Admin users/machines/maintenance/shifts. Historical records have protected deletion paths. A manual browser/device walkthrough remains outstanding. |

## Validation

Tests use in-memory databases, temporary workflow stores or mocked external integrations. No operational payment/email/inventory services were invoked.

| Command/check | Result |
| --- | --- |
| Backend tests excluding PostgreSQL fixture | 67 passed, 0 failed |
| Isolated PostgreSQL 18 tests | 3 passed: migrations/schema retention plus two receipt concurrency cases. A later relaunch was denied permission to bind a local test socket; no production database was used. |
| `.venv/Scripts/python.exe -m pytest ai/tests -q` | 78 passed; one Starlette/anyio deprecation warning remains in a dependency |
| `npm run build` in frontend | Passed; approximately 1.10 MB main JS chunk warning |
| `npm test` in frontend | 7 passed across 3 files |
| `npm run lint` in frontend | Passed, 0 errors and 0 warnings |
| `flutter test --no-pub` in mobile_flutter | 40 passed |
| `flutter analyze` | Passed, no issues |
| Fresh forward migrations on isolated PostgreSQL 18 | Passed; all mapped columns present, rerun retained seeded machine data |
| `git diff --check` | Passed; Windows line-ending notices only |

React lint has a flat configuration and passes without disabling the findings discovered during the audit.

## Historical data and migrations

Removed historical inventory/order DELETE statements from the recovered catalogue-reset migration. Null packaging links retain their records with an inactive “Unassigned historical catalogue” marker exposed by reconciliation.

Excluded the experimental AlignmentTemporary/ManufacturingAlignmentTemporary migration directories from compilation: they duplicate existing schema changes and alter historical identities. `docs/temporary-alignment.sql` was not executed and must not be used as a deployment script.

New forward migrations add missing procurement schema with IF NOT EXISTS and enforce normalized roll identity plus one PO per procurement request. Historical duplicates cause the unique migration to fail for manual reconciliation; no records are automatically deleted. Schema completion has a non-destructive no-op downgrade.

Migrations were applied only to disposable PostgreSQL 18 databases created by the integration tests. They were rerun and retained seeded records. If the old destructive migration already ran in another environment, these edits cannot restore deleted records; a backup is required.

## Remaining work

1. Run the migrations against a sanitized copy of the target deployment and manually reconcile any unknown or duplicate historical mappings before production rollout.
2. Complete authenticated React/browser and Flutter/device walkthroughs for every role and refresh/error path. Current evidence is automated HTTP, component, service and widget testing.
3. Code-split the approximately 1.10 MB React main bundle if initial-load performance is a release requirement.
4. Run a staging restart drill with the backend and multiple AI workers. Separate-process locking is automated and passing, but the full deployed topology was not started here.

No real payments, supplier emails or live inventory mutations were performed. Changes remain reviewable on `Merge`; `main` is unchanged.
