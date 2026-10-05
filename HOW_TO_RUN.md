> Updated integration and role guidance: see [README.md](README.md) and [Student components](docs/STUDENT_COMPONENTS.md).

# How to Run the Full Stack

> Run **3 terminals** at the same time — one for each service.

---

## Prerequisites

- **PostgreSQL** running on `localhost:5432`, database `inventory_coordinator`
- **Node.js** ≥ 18
- **.NET 8 SDK**
- **Python 3.11+** with a virtual environment set up in `ai/venv/`

---

## Step 1 — Set up `backend/.env`

Make sure `backend/.env` exists with these values:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=inventory_coordinator
DB_USER=postgres
DB_PASSWORD=<SET_LOCALLY_DO_NOT_COMMIT>

EMAIL_USER=<YOUR_SMTP_USER>
EMAIL_PASS=<SET_LOCALLY_DO_NOT_COMMIT>

JWT_SECRET_KEY=<SET_LOCALLY_DO_NOT_COMMIT>
JWT_ISSUER=InventoryCoordinatorAPI
JWT_AUDIENCE=InventoryCoordinatorClient

STRIPE_SECRET_KEY=<SET_LOCALLY_DO_NOT_COMMIT>

# ⚠️ Replace with your actual OpenAI key for the AI agent to work
OPENAI_API_KEY=<SET_LOCALLY_DO_NOT_COMMIT>
```

---

## Terminal 1 — Backend (ASP.NET Core)

```powershell
cd backend
dotnet run
```

- Starts at: `http://localhost:5070`
- Swagger UI: `http://localhost:5070/swagger`
- Auto-creates all DB tables and seeds data on first run

---

## Terminal 2 — Frontend (React + Vite)

```powershell
cd frontend
npm install        # only needed first time
npm run dev
```

- Opens at: `http://localhost:5173`

---

## Terminal 3 — AI Agent (Python FastAPI)

```powershell
# Run from the repository root
.\ai\venv\Scripts\activate

# Install dependencies (only needed first time)
pip install -r ai/requirements.txt   # or: pip install fastapi uvicorn langgraph langchain-openai psycopg httpx scikit-learn numpy pydantic-settings

# Start the server
uvicorn ai.main:app --host 127.0.0.1 --port 8000 --reload
```

- Starts at: `http://localhost:8000`
- Docs: `http://localhost:8000/docs`

If replenishment reports **connection refused (localhost:8000)**, the Python AI
service is not running. Start it with the command above and check it before retrying:

```powershell
Invoke-RestMethod http://localhost:8000/health
```

The response should contain `status: ONLINE`. Keep the AI terminal running alongside
ASP.NET Core and React. Restart the backend and AI service after pulling changes to
their workflow contracts; an old backend build may lack the workflow publication API.

---

## Service Map

| Service | Port | URL |
|---------|------|-----|
| ASP.NET Backend | 5070 | `http://localhost:5070/api/*` |
| React Frontend | 5173 | `http://localhost:5173` |
| Python AI Agent | 8000 | `http://localhost:8000` |

---

## AI Endpoints (all in one process)

| Endpoint | Used by | Purpose |
|----------|---------|---------|
| `GET /health` | AdminService.cs | Service health check |
| `POST /api/predict` | AgentIntegrationService.cs | ML risk scoring for inventory |
| `POST /api/agent/extract-data` | Direct | LangGraph data extraction pipeline |
| `POST /quality/recommendation` | defectService.js | AI defect quarantine recommendation |
| `POST /api/workflows/run` | AdminService.cs | Trigger full AI workflow |
| `GET /api/workflows` | AdminService.cs | List active workflows |
| `POST /api/workflows/{id}/approve` | AdminService.cs | IT Admin approves workflow |
| `POST /api/workflows/{id}/reject` | AdminService.cs | IT Admin rejects workflow |
| `GET /api/tools/production-schedule` | Direct | Production schedule tool |
| `GET /api/tools/machine-uptime` | Direct | Machine uptime tool |

---

## Default Login Accounts (seeded)

| Role | Email | Password |
|------|-------|----------|
| Supply Chain Manager | manager@amic.com | Password123! |
| Quality Inspector | quality@amic.com | Password123! |
| Production / IT Admin | admin@amic.com | Password123! |
| Floor Worker | worker@amic.com | Password123! |

> Accounts are seeded on first `dotnet run`. Check `DbInitializer.cs` for details.

