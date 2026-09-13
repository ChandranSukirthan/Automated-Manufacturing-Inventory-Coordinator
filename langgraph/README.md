# Manufacturing Coordinator LangGraph

Standalone AI orchestration workspace for the Automated Manufacturing Inventory Coordinator.

## Part 1 scope

This scaffold is for the AI/LangGraph implementation only. Existing SE applications remain separate and unchanged:

- `backend/`: ASP.NET Core API, authentication, authorization, inventory, defects, and quarantine workflows.
- `frontend/`: React client for operational and quality workflows.
- `mobile_flutter/`: Flutter client for batch, defect, and quarantine workflows.

## Mandatory agents

The project retains exactly four mandatory agents:

1. Planner
2. Data Extraction
3. Purchasing
4. Validation/Safety

Student 3 owns tools used by the Validation/Safety Agent. Future quality tools belong in `tools/quality/`; they are intentionally not implemented in Part 1.

## Inspected quality contract

The existing API exposes quality operations under authenticated `QualityInspector` endpoints:

- `GET/POST/PUT/DELETE /api/defects`
- `GET /api/defects/{id}`
- `POST /api/defects/{id}/quarantine`
- `GET /api/quarantine`
- `GET /api/quarantine/{id}`
- `POST /api/quarantine/{id}/release`
- `GET /api/batches/{id}`
- `GET /api/dashboard/quality/summary`

Relevant domain values include `ProductType`, `DefectSeverity`, `DefectStatus`, `QuarantineStatus`, and `InventoryStatus`, together with `DefectReport`, `Quarantine`, `Batch`, and `InventoryRoll`.

## Future setup

1. Create a Python environment.
2. Install dependencies from `requirements.txt`.
3. Copy `.env.example` to `.env` and configure the backend URL and credentials.
4. Implement quality tools under `tools/quality/` and expose them only through `agents/validation_safety.py`.

No agent graph or quality tool behavior is implemented yet.
