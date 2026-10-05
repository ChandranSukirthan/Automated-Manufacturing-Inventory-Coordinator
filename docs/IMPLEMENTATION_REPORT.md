# Integration implementation and verification report

Review date: 2026-10-05. Changes remain uncommitted on the existing Merge branch; existing user changes were preserved. This report describes repository implementation and measured tests, not a grading guarantee or a live deployment.

## Implemented fixes

1. Preserved the existing four AI responsibilities and canonical LangGraph. Planner coordinator routing handles specialist results, with a maximum of three total supplier selections. QA, missing data and service failures take the appropriate correction path rather than an infinite supplier loop.
2. Manual requests retain a positive explicit requested quantity even when inventory is healthy. Automatic low-stock requests use the authoritative deficit and existing idempotent workflow/receipt controls.
3. Purchasing and independent validation now share approved/internal supplier preference and actual rounded order-cost ranking. Zero-day delivery is retained; MOQ/pack-size rounding is reflected in cost/availability. Currency/unit disagreement is rejected instead of implicitly converted.
4. Inventory tools validate finite output, reject invalid material identifiers instead of rewriting them, use a seven-day predictive warning before supplier selection, preserve safety stock during supplier lead time and explicitly report unknown coverage for zero consumption. Supplier selection rechecks coverage against delivery lead time.
5. Production schedules now have nullable catalogue material, machine and material-per-output association fields. A forward migration preserves old records. The graph chooses a material-specific schedule and calculates output using its stored conversion. Missing context is reported, not replaced by a global unrelated shift. React supports the fields; Flutter maps productionTarget correctly and no longer fabricates an active production shift when none exists.
6. FastAPI no longer writes workflow/procurement outcome tables directly. Signed, authenticated, bounded state publication goes through ASP.NET Core. SQLite retains failed publication, exposes SYNC_PENDING and supports authorized publication retry. Fresh approval is blocked when publication is still unavailable. Actual payment/delivery learning outcomes belong to the backend lifecycle. Backend publication preserves QA decisions over stale AI state and excludes private prompt/token fields.
7. Draft creation checks the complete required financial/business evidence rather than trusting only isValid. QA clearance cannot override supplier, quantity, budget, mathematics or other failed proposal checks. Backend inventory/quarantine enforcement remains authoritative.
8. Internal quality, extraction, prediction and production-tool HTTP routes require backend authentication; the quality recommendation endpoint also requires QualityInspector. Backend quality analysis forwards authentication. FastAPI browser CORS is disabled, local default binding is loopback, backend browser origins are constrained, and database tool reads have statement timeouts/read-only transactions.
9. Draft/production/quarantine output contracts validate results and record tool timing/failure summaries; graph handoffs record duration. Structured session persistence recursively excludes prompts, tokens and private fields. No chain-of-thought is stored.
10. Mobile access/refresh tokens moved from SharedPreferences to platform secure storage, with tested legacy migration/logout. Android backup is disabled. The unused direct FastAPI mobile base URL was removed. Tracked setup/config credential values were removed; real credential rotation remains an owner action.
11. Added bounded database paging/search/sort endpoints for inventory, suppliers, machines, defects and purchase orders without changing old list-array responses. React supplier paging is integrated with cancellation of stale searches. Other client lists remain compatible with their current endpoints.
12. Retained role-layout/nav overlap fixes and added route-level lazy loading. The React main JS build chunk fell from approximately 1114.56 KB to 285.99 KB; total application code is still loaded as needed, so this is not a claim that the total application became that small.
13. CI covers main, Merge and student AI branches, provisions disposable PostgreSQL for relational tests, runs all four stack checks and uploads test/performance/build artifacts. Prepared Docker service-network packaging and setup/architecture/component documentation.

## Verification actually run

| Check | Result | Boundary |
|---|---|---|
| Python/FastAPI/LangGraph | 110 passed | Real graph nodes and contracts; external inventory/supplier/model boundaries explicitly mocked in offline tests |
| ASP.NET Core/xUnit | 79 passed, 0 skipped | Includes real disposable PostgreSQL migration/schema/idempotency checks; manual CRUD HTTP tests use signed roles and isolated services |
| React/Vitest | 17 passed | Includes role shell, worker replenishment and supplier server-paging contracts |
| React production build | Passed | Route chunks generated; largest main JS chunk approx 285.99 KB |
| Flutter unit/widget tests | 43 passed | Includes secure-session migration/logout and nested procurement shell behavior |
| Flutter static analysis | No issues found | New dependency/package lock restored |
| Local API timing | 50 measured requests, 1000 suppliers | ASP.NET TestServer + EF InMemory; see evidence JSON, not cloud/real PostgreSQL load performance |

PostgreSQL 18.4 ran in a separate disposable cluster on loopback port 55432. Tests created/dropped isolated test databases. The user's existing project database and running backend were not migrated or stopped. The disposable server was shut down after verification.

The performance evidence JSON records the actual measured environment, mean/p95/max and timestamp. It is intentionally not generalized into a production latency promise. CI regenerates this evidence. Deprecation warnings remain in third-party Python libraries, and browser-test navigation notices do not indicate failed tests.

## What must be checked manually before submission

- Restart the updated backend/AI services and apply the new forward migration to a backed-up project database before using shift associations. Existing development services were left running with their prior binaries.
- Review every role's real screens/CRUD with the team's own records. Configure real material units, shift associations, consumption history, active supplier quotes and budgets; empty/demo data is not operating evidence.
- Verify an automatic low-stock request, a manual request with healthy stock, valid manager approval, rejected proposal, bounded supplier retries, QA hold/release and backend rejection of unsafe inventory despite a safe AI response.
- Verify provider-dependent grounded research, payment/email sandbox behavior and receipt lifecycle with actual configured accounts. No real payment/email/provider success is claimed by offline tests.
- Test secure storage and the new mobile build on a target device. On this Windows host, the package tool reported missing Developer Mode/symlink support; a fresh APK with the new plugin was not built. Existing APK files are not evidence of these latest changes.
- Rotate any credentials previously exposed in repository history. Values removed from current tracked files are not automatically revoked at the provider.
- Fill each student's genuine contribution/AI-use/reflection evidence and record the project walkthrough. Architecture/code/test documentation cannot replace individual viva/demo/report evidence required by the marking scheme.
- Live deployment is intentionally deferred at the user's request until manual role checks. Docker packaging is prepared but not built here because Docker is unavailable. No cloud target/domain, paid resources or signed release were created.

## Per-student review

See [STUDENT_COMPONENTS.md](STUDENT_COMPONENTS.md) for each student's normal workflow, CRUD/business operations, individual AI tool slice, cooperative responsibility and implementation paths. See [SETUP_AND_DEPLOYMENT.md](SETUP_AND_DEPLOYMENT.md) before restarting/migrating the updated project.
