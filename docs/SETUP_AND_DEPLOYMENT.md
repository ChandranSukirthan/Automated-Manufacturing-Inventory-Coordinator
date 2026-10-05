# Setup and deployment

## Local setup

Use .NET SDK 8, Node 22/pnpm (lockfile retained), Python 3.12+ and Flutter matching the Dart >=3.12 constraint. Restore backend dependencies with `dotnet restore backend/Tests/backend.Tests.csproj`; create a Python virtual environment and install `ai/requirements.txt`; run `pnpm install --frozen-lockfile` in `frontend` and `flutter pub get` in `mobile_flutter`.

Configure the ignored `backend/.env` with DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET_KEY, JWT_ISSUER, JWT_AUDIENCE, EMAIL_USER, EMAIL_PASS and the provider keys actually needed. Use an independently generated strong signing key and the same issuer/audience/signing key in ASP.NET Core and FastAPI. Do not put secrets in tracked appsettings or documentation. Values removed from tracked examples may still exist in Git history: the owner must rotate previously disclosed provider/JWT credentials; source cleanup alone is not rotation.

Run the backend from its project directory so dotenv finds `backend/.env`. The backend uses `AgentServer:BaseUrl` (environment `AgentServer__BaseUrl`) for FastAPI. FastAPI uses BACKEND_HOST (default localhost:5070), INVENTORY_API_URL and scoped forwarded bearer credentials to read stock and publish state. On a workstation bind FastAPI to 127.0.0.1; neither React nor Flutter should address port 8000.

From the repository root: `python -m uvicorn ai.main:app --host 127.0.0.1 --port 8000`. Start ASP.NET Core with `dotnet run --project backend/ManufacturingCoordinator.Api.csproj`. Start React with `pnpm dev` from `frontend`. For Android emulator use API_BASE_URL=http://10.0.2.2:5070/api; a physical phone needs the reachable backend address. Configure an HTTPS API for release builds.

FastAPI stock monitoring requires AMIC_MONITOR_TOKEN from an authorized backend session. Do not commit it. A expired monitor token stops authenticated operations; the health of monitoring must be checked during deployment. Supplier research is optional, requires a valid Gemini key/model supporting Google Search, and refuses responses without grounded sources. Internal approved supplier procurement works without an external model call.

## Migration and production context

The forward migration `20261005010000_AddShiftMaterialContext` adds nullable MaterialSku, MachineId and MaterialPerUnit to Shifts. It does not rewrite historical shifts or drop data. Back up the target and apply the migration before using the new shift fields. The backend startup currently applies migrations; restart the updated backend when ready. No migration was applied to the user's existing project database during this review.

For accurate production AI analysis, edit/create a shift with its catalogue material, machine and material used per finished unit. Old capacity-only shifts remain readable and retain their legacy calculation. The cooperative graph chooses a matching material schedule; missing conversion is reported as unavailable rather than treating raw-material kilograms as finished units.

Existing client list APIs still return arrays. New bounded endpoints are `/api/inventory/paged`, `/api/suppliers/paged`, `/api/machines/paged`, `/api/defects/paged` and `/api/purchase-orders/paged`. Query parameters include page, pageSize (1–100), search (up to 100 characters), sort and direction; supplier status supports active/inactive/all. Sort fields should be selected according to the resource. React supplier lists use these endpoints. Other existing lists retain their client contracts.

## Security and publication

FastAPI has no browser CORS permission. Workstation binding is loopback; in containers it may bind to a private service network only. AI database reads use fixed parameterized queries, bounded statement timeouts and read-only tool transactions. Provision a database login restricted to SELECT on required inventory, supplier, production and quality tables; deployment role provisioning is an operator step.

Workflow writes now use `PUT /api/internal/workflows/{workflowId}/state`. It requires an authorized backend bearer token and a short-lived HMAC signature over the exact JSON state. No model sees the signing key or arbitrary SQL. The backend accepts a bounded execution summary, preserves authoritative QA decisions and never creates/approves orders through the publication endpoint. SQLite retains pending state; API output shows SYNC_PENDING and approval is blocked if publication cannot succeed. Retry/revalidation under an authorized session retries publication. JWTs are not stored for unattended retries.

Flutter sessions use platform secure storage. Legacy plaintext preferences migrate and are removed only after a successful secure write. Android backup is disabled. Android builds using the new plugin require Windows symlink support/Developer Mode (the dependency tool reported it unavailable on this host). Unit/widget tests and static analysis do not prove encrypted storage behavior on a physical device; verify login, migration and logout on the target phone.

Backend browser origins now use Cors:AllowedOrigins; local development also accepts localhost/127.0.0.1. Configure the exact deployed web origin, not a wildcard. Release mobile HTTPS and the reverse proxy's TLS settings remain deployment tasks.

## Deployment package and evidence

Dockerfiles and `deploy/compose.yml` prepare a local service-network deployment: only the web gateway/backend ports are published, FastAPI remains internal, and database/workflow state use persistent volumes. These files were reviewed but not container-built because Docker is unavailable on this host. Configure real secrets in the ignored deployment env file and review the hosted target's networking, HTTPS, storage, backups and startup migrations before running it.

A cloud hostname/account, repository deployment credentials, a release signing configuration and actual-device demo evidence have not been supplied. No public deployment, credential rotation, signed APK or recorded walkthrough is claimed. CI produces test/build/APK artifacts; a hosting-specific deployment job requires that concrete target.

## Verification commands

- AI: `python -m pytest ai/tests -q`
- Backend: `dotnet test backend/Tests/backend.Tests.csproj`; set AMIC_TEST_POSTGRES to a **disposable** cluster to include relational tests, which create and drop isolated test databases.
- React: `pnpm test` and `pnpm build` in frontend.
- Flutter: `flutter analyze` and `flutter test` in mobile_flutter.

When the running backend locks its executable, use a separate test OutputPath and UseAppHost=false rather than stopping the user's service. Offline graph tests replace external boundaries explicitly; they do not constitute live provider/payment/email evidence.
