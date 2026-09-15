# AMIC Quality AI Service

The `ai/` module provides the implemented Quality AI capability for the Automated Manufacturing Inventory Coordinator (AMIC). It validates defect context, retrieves related inventory from PostgreSQL, and produces a read-only quarantine recommendation for the application clients.

The service is deterministic. It does not call an LLM, modify production data, or perform quarantine enforcement.

## Scope and Architecture

The required AMIC agent architecture remains:

1. Planner
2. Data Extraction
3. Purchasing
4. Validation/Safety

Quality is subordinate functionality used by the Validation/Safety layer. In the current repository, there is no complete team LangGraph graph containing those four agents. The implemented `quality_agent.py` is an AgentState-compatible Validation/Safety helper; it is not a fifth mandatory agent.

```text
Quality Inspector defect form
            |
            v
POST /quality/recommendation
            |
            v
Validation/Safety helper
            |
            +--> analyze_defect_context()
            |
            +--> check_related_inventory()
            |
            +--> recommend_quarantine()
            |
            v
quality_data + tool_results
            |
            v
Recommendation returned to React or Flutter
            |
            v
ASP.NET Core deterministic validation
            |
            v
Authorized backend/database mutation, when explicitly requested
```

The Python service stops at the recommendation and validation-signal boundary. The ASP.NET Core backend remains authoritative for authorization, quarantine rules, inventory status changes, and database mutation.

## Implemented Components

```text
ai/
├── core/
│   ├── config.py       Environment-backed PostgreSQL settings
│   └── state.py        Shared AgentState and status enums
├── tools/
│   └── quality_tools.py
├── agents/
│   └── quality_agent.py  Validation/Safety subordinate helper
├── routes/
│   └── quality_routes.py
├── tests/
│   └── test_quality_integration.py
├── requirements.txt
└── main.py
```

## Quality Tools

The public Quality tool set contains exactly three tools.

### `analyze_defect_context()`

Validates the required defect input and produces a deterministic quarantine assessment.

Supported product types:

- `BoxPouch`
- `BiscuitPackaging`
- `TeaBag`
- `Bag`
- `Can`
- `Bottle`

Supported severities are case-insensitively normalized for validation:

- `Low`
- `Medium`
- `High`
- `Critical`

The implemented rules are:

- `High` and `Critical` require quarantine recommendation.
- A normal `Low` defect does not automatically require quarantine.
- `Medium` can require quarantine when the description contains a serious safety term or previous severe defect history exists.
- Invalid product types, severities, missing fields, and empty descriptions raise validation errors.
- Previous severe defect history is read from `DefectReports` when a database connection is available.

### `check_related_inventory()`

Reads the batch and its related inventory rolls from the existing PostgreSQL schema:

- `Batches.Id`
- `InventoryRolls.Id`
- `InventoryRolls.BatchId`
- `InventoryRolls.Status`

An unknown batch raises a safe validation error. An existing batch with no inventory rolls returns an empty `affectedInventory` list.

### `recommend_quarantine()`

Combines the defect context and related inventory into a recommendation. It does not create a quarantine record or change inventory status.

## Example Request and Response

Request:

```http
POST /quality/recommendation
Content-Type: application/json
```

```json
{
  "batchId": "BATCH111",
  "productType": "BoxPouch",
  "severity": "High",
  "description": "Material defect detected"
}
```

Response for the seeded local test data:

```json
{
  "batchId": "BATCH111",
  "quarantineRequired": true,
  "affectedInventory": [
    "ROLL11",
    "ROLL12"
  ],
  "riskLevel": "HIGH"
}
```

A recommendation is not an enforcement command. The response only reports a safety signal to the caller.

## AgentState and Validation/Safety

`ai/core/state.py` defines the shared `AgentState` shape with these fields:

- `workflow_id`
- `objective`
- `current_agent`
- `status`
- `approval_status`
- `inventory_data`
- `production_data`
- `purchasing_data`
- `quality_data`
- `tool_results`
- `final_outcome`
- `errors`
- `requires_approval`

The Quality helper reads the defect from:

```python
state["quality_data"]["defect"]
```

It stores results in:

```python
state["quality_data"]["recommendation"]
state["quality_data"]["validation"]
state["tool_results"]["recommend_quarantine"]
```

The helper marks its stage as `Validation/Safety`. If the related inventory is already quarantined, it returns the deterministic safety result:

```json
{
  "valid": false,
  "riskLevel": "HIGH",
  "reason": "Associated inventory is quarantined"
}
```

It also validates optional purchasing data supplied through shared state, including supplier, quantity, budget, and caller-provided business-rule limits.

## PostgreSQL Context Retrieval

Database settings are loaded by `ai/core/config.py` from the existing repository backend configuration at `backend/.env`. The password is not stored in Python source code and is not documented here.

The Quality service uses `psycopg` and read-only `SELECT` queries for:

- Batch existence
- Related inventory IDs
- Previous severe defect history
- Existing quarantined inventory status

The AI service does not execute `INSERT`, `UPDATE`, or `DELETE` statements. It does not:

- Change `InventoryRolls.Status`
- Create `Quarantines` records
- Release quarantined inventory
- Modify purchase orders
- Change authorization or RBAC
- Bypass ASP.NET Core business rules

## HTTP API

### `GET /health`

Returns a service health response:

```json
{
  "status": "ok"
}
```

### `POST /quality/recommendation`

Accepts a defect payload with:

- `batchId`
- `productType`
- `severity`
- `description`

The route calls the existing Validation/Safety helper and returns its `quality_data["validation"]` result. Validation and database connection failures are returned as controlled HTTP 400 responses.

The service enables narrowly scoped CORS for the local React development origins:

- `http://localhost:5173`
- `http://127.0.0.1:5173`

## Client Integrations

### React web client

The Quality defect form in `frontend/src/pages/Dashboard/DefectFormPage.jsx` provides an **Analyze with AI** action. It sends the four required JSON fields through `frontend/src/services/defectService.js`.

The AI base URL is configurable with:

```text
VITE_AI_API_BASE_URL
```

The browser default is:

```text
http://127.0.0.1:8000
```

The React client displays:

- Risk level
- Whether quarantine is required
- Affected inventory IDs
- Loading, validation, network, and service errors

The action only requests and displays a recommendation. Existing defect CRUD and quarantine operations continue to use the ASP.NET Core API client.

### Flutter mobile client

The Flutter defect form in `mobile_flutter/lib/screens/defect_form_screen.dart` provides the same **Analyze with AI** action. `QualityService.analyzeDefect()` calls the shared AI endpoint through `ApiClient.postAi()`.

The AI base URL is configurable at build time:

```text
--dart-define=AI_API_BASE_URL=http://10.0.2.2:8000
```

The default is `http://10.0.2.2:8000`, which allows an Android emulator to reach the host machine. The existing backend API URL remains separately configurable through `API_BASE_URL`, for example:

```text
--dart-define=API_BASE_URL=http://10.0.2.2:5070/api
```

Flutter reuses its existing authenticated `ApiClient`, including bearer headers and token refresh behavior. The AI action only displays the recommendation and does not call quarantine mutation endpoints.

## ASP.NET Core Authority

The ASP.NET Core backend remains the enforcement layer. Its existing Quality Inspector authorization protects defect and quarantine operations. The backend quarantine service validates defect existence, inventory availability, batch ownership, duplicate quarantine state, and inventory status before making any database mutation.

The intended boundary is:

```text
AI recommendation
        |
        v
ASP.NET Core authorization and deterministic validation
        |
        v
Database mutation, only through the authorized backend workflow
```

The Python AI service does not duplicate or bypass this enforcement.

## Technology Stack

- Python 3.11-3.13 target runtime
- FastAPI
- Uvicorn
- Pydantic
- Pydantic Settings
- PostgreSQL
- `psycopg[binary]`
- LangGraph and LangChain dependencies declared for shared project compatibility
- React and Axios client integration
- Flutter and the existing `http`-based API client
- pytest

The current Quality implementation itself is deterministic and does not make an LLM call.

## Run the AI Service

From the repository root, use the Python 3.12 virtual environment:

```powershell
.\ai\.venv\Scripts\Activate.ps1
uvicorn ai.main:app --reload --port 8000
```

The service is available at:

- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/docs`
- `http://127.0.0.1:8000/quality/recommendation`

## Tests

Run the deterministic Quality tests with the project virtual environment:

```powershell
.\ai\.venv\Scripts\python.exe -m compileall -q ai
.\ai\.venv\Scripts\python.exe -m pytest -q
```

The test suite covers:

- Golden High-severity recommendation
- Critical and Low severity behavior
- Invalid product type and severity
- Unknown batches
- Existing batches without inventory
- Existing quarantined inventory
- Deterministic Validation/Safety rejection
- Read-only SQL behavior
- FastAPI route behavior
- Exactly three Quality tools
- Exactly four mandatory agent names

The full team LangGraph graph is not present in this repository, so these tests validate the implemented Quality tools, helper, state contract, and FastAPI route rather than full graph execution.
