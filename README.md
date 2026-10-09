# Automated Manufacturing Inventory Coordinator

Integrated ASP.NET Core/PostgreSQL application with React, Flutter and an internal FastAPI/LangGraph service. The four mandatory AI responsibilities remain Planner, Data Extraction, Purchasing and Validation/Safety. Production analysis and supervisor routing are functions within the planner/coordinator responsibility.

- [Student ownership, CRUD and AI workflows](docs/STUDENT_COMPONENTS.md)
- [Setup, migration and deployment](docs/SETUP_AND_DEPLOYMENT.md)
- [Architecture decisions and data relationships](docs/ARCHITECTURE_DECISIONS.md)
- [Fixes, test evidence and remaining submission evidence](docs/IMPLEMENTATION_REPORT.md)
- [CI checks](docs/CI_CD.md)

From the repository root, run `dotnet run --project backend/ManufacturingCoordinator.Api.csproj`, then `python -m uvicorn ai.main:app --host 127.0.0.1 --port 8000`, and run `pnpm dev` in `frontend`. Configure the ignored backend `.env` first. Use Node 22, .NET 8 and the Flutter version compatible with `mobile_flutter/pubspec.yaml` (Dart >=3.12). Flutter and React call ASP.NET Core; they do not call FastAPI.

Both automatically detected low stock and a manual request can initiate procurement. Manual replenishment is allowed even when current stock is healthy. Only a fully validated and published proposal reaches manager review. Supplier selection is limited to three total attempts. QA holds and unavailable services require the appropriate corrective action; changing supplier does not resolve a quarantine.

The current changes are on the existing `Merge` branch. They do not create separate student workflows or claim a cloud deployment.

yes 