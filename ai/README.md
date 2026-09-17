# AMIC Production AI Microservice

Agentic AI Coordinator service for **Automated Manufacturing Inventory Coordinator (AMIC)**.  
Built with **FastAPI**, **LangGraph**, and **PostgreSQL** on **Port 5070**.

---

## 🚀 Features

1. **Planner / Coordinator Agent:** Decomposes complex factory objectives into sequential operational steps using GPT-4o-mini with intelligent fallback heuristics.
2. **Production Telemetry Tools:** 4 dedicated database tools querying schedules, machine uptimes, service intervals, and material capacity constraints.
3. **Enterprise Safety & Validation Gate:** Halts high-risk or high-cost actions (cost > $1,000, supplier unavailability) and pauses for IT Admin human authorization (`WaitingForApproval`).
4. **Autonomous Equipment Telemetry Scanner:** Background service running every 10 seconds that continuously monitors the factory floor. When any machine breaches its service threshold, the AI autonomously initiates an overhaul workflow (`WF-AUTO-...`) awaiting IT Admin approval.
5. **Real-Time PostgreSQL Synchronization:** Automatically syncs state changes to the `AgentWorkflows` table in the database.

---

## 🛠️ Setup & Installation

### 1. Prerequisites
* Python 3.11, 3.12, or 3.13
* PostgreSQL running locally on port `5432` with database `inventory_coordinator`

### 2. Environment Configuration
Create a `.env` file in the `ai/` directory from `.env.example`:
```bash
cp .env.example .env
```
Update `.env` with your PostgreSQL password and OpenAI API key:
```ini
DB_HOST=localhost
DB_PORT=5432
DB_NAME=inventory_coordinator
DB_USER=postgres
DB_PASSWORD=your_password
FASTAPI_HOST=127.0.0.1
FASTAPI_PORT=5070
OPENAI_API_KEY=your_openai_api_key
```

### 3. Create Virtual Environment & Install Dependencies
```powershell
cd ai
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

---

## 🏃 Running the Service

Start the FastAPI application with live reload:
```powershell
uvicorn main:app --host 127.0.0.1 --port 5070 --reload
```

* **Interactive Swagger Documentation:** [http://127.0.0.1:5070/docs](http://127.0.0.1:5070/docs)
* **Service Health Check:** [http://127.0.0.1:5070/health](http://127.0.0.1:5070/health)

---

## 🧪 Running Automated Tests

Run the golden test suite verifying all 8 core workflows, tool calculations, and safety gates:
```powershell
pytest tests/test_golden.py -v
```

---

## 📡 REST API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/workflows/run` | Dispatches an operational objective to the Planner Agent |
| `POST` | `/api/workflows/{workflow_id}/approve` | Resumes a paused workflow after IT Admin authorization |
| `POST` | `/api/workflows/{workflow_id}/reject` | Rejects a paused workflow at the human approval gate |
| `GET` | `/api/workflows/{workflow_id}` | Fetches real-time status and telemetry of an active workflow |
| `GET` | `/api/tools/production-schedule` | Queries shift targets and equipment assignments |
| `GET` | `/api/tools/machine-uptime` | Evaluates machine operating hours and remaining service time |
| `GET` | `/api/tools/maintenance-requirement` | Evaluates if a machine is overdue for preventive maintenance |
| `POST` | `/api/tools/production-impact` | Computes output adjustments due to material constraints |
| `GET` | `/health` | Health check endpoint for ASP.NET Core backend |
