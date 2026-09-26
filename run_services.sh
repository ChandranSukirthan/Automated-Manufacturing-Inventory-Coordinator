#!/usr/bin/env bash

# ==============================================================================
# Automated Manufacturing Inventory Coordinator (AMIC)
# Multi-Service Turnkey Launcher Script
# ==============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}   Automated Manufacturing Inventory Coordinator (AMIC) Launcher  ${NC}"
echo -e "${CYAN}==================================================================${NC}"

usage() {
    echo -e "Usage: $0 [all | backend | ai | frontend | flutter]"
    echo ""
    echo "Options:"
    echo "  all       Start Backend, AI Service, and Frontend concurrently in background"
    echo "  backend   Run ASP.NET Core API (port 5070)"
    echo "  ai        Run Python FastAPI AI multi-agent service (port 8000)"
    echo "  frontend  Run React / Vite Web Console (port 5173)"
    echo "  flutter   Run Flutter Mobile Application"
    echo ""
    exit 1
}

start_backend() {
    echo -e "${BLUE}▶ Starting Backend (ASP.NET Core Web API on http://localhost:5070)...${NC}"
    cd "$PROJECT_ROOT/backend" || exit 1
    dotnet run --project ManufacturingCoordinator.Api.csproj --launch-profile http
}

start_ai() {
    echo -e "${GREEN}▶ Starting AI Service (Python FastAPI on http://localhost:8000)...${NC}"
    cd "$PROJECT_ROOT/ai" || exit 1
    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    fi
    uvicorn ai.main:app --host 0.0.0.0 --port 8000 --reload
}

start_frontend() {
    echo -e "${YELLOW}▶ Starting Frontend (React / Vite on http://localhost:5173)...${NC}"
    cd "$PROJECT_ROOT/frontend" || exit 1
    npm run dev
}

start_flutter() {
    echo -e "${CYAN}▶ Starting Flutter Mobile App...${NC}"
    cd "$PROJECT_ROOT/mobile_flutter" || exit 1
    echo -e "Choose target device:"
    echo "  1) Chrome (Web)"
    echo "  2) Android Emulator (emulator-5554)"
    echo "  3) macOS Desktop"
    read -p "Selection [1-3, default 1]: " dev_choice
    case $dev_choice in
        2)
            flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5070/api
            ;;
        3)
            flutter run -d macos --dart-define=API_BASE_URL=http://localhost:5070/api
            ;;
        *)
            flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5070/api
            ;;
    esac
}

start_all() {
    echo -e "${CYAN}▶ Launching Backend, AI Engine, and React Frontend in background...${NC}"

    # 1. AI Service
    echo -e "${GREEN}[1/3] Launching Python FastAPI AI Engine (port 8000)...${NC}"
    cd "$PROJECT_ROOT/ai" && (
        if [ -f ".venv/bin/activate" ]; then source .venv/bin/activate; fi
        uvicorn ai.main:app --host 0.0.0.0 --port 8000 --reload
    ) > "$PROJECT_ROOT/ai_service.log" 2>&1 &
    AI_PID=$!
    echo -e "      Python AI PID: $AI_PID (logs: ai_service.log)"

    # 2. Backend
    echo -e "${BLUE}[2/3] Launching ASP.NET Core API (port 5070)...${NC}"
    cd "$PROJECT_ROOT/backend" && (
        dotnet run --project ManufacturingCoordinator.Api.csproj --launch-profile http
    ) > "$PROJECT_ROOT/backend_service.log" 2>&1 &
    BACKEND_PID=$!
    echo -e "      Backend PID: $BACKEND_PID (logs: backend_service.log)"

    # 3. Frontend
    echo -e "${YELLOW}[3/3] Launching React Vite Frontend (port 5173)...${NC}"
    cd "$PROJECT_ROOT/frontend" && (
        npm run dev
    ) > "$PROJECT_ROOT/frontend_service.log" 2>&1 &
    FRONTEND_PID=$!
    echo -e "      Frontend PID: $FRONTEND_PID (logs: frontend_service.log)"

    echo ""
    echo -e "${GREEN}✔ All services started!${NC}"
    echo "--------------------------------------------------"
    echo "  • ASP.NET Core API:  http://localhost:5070/swagger"
    echo "  • FastAPI AI Engine: http://localhost:8000/docs"
    echo "  • React Frontend:    http://localhost:5173"
    echo "--------------------------------------------------"
    echo -e "${YELLOW}To stop all services, run:${NC}"
    echo "  kill $AI_PID $BACKEND_PID $FRONTEND_PID"
    echo ""
    echo "Press Ctrl+C to stop watching logs."
    tail -f "$PROJECT_ROOT/backend_service.log"
}

case "$1" in
    all)
        start_all
        ;;
    backend)
        start_backend
        ;;
    ai)
        start_ai
        ;;
    frontend)
        start_frontend
        ;;
    flutter)
        start_flutter
        ;;
    *)
        usage
        ;;
esac
