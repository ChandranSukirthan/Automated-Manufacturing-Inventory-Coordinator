from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from ai.routes.quality_routes import router as quality_router
from ai.routes.workflow_routes import router as workflow_router, tools_router


app = FastAPI(title="AMIC AI Service")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5070",
        "https://localhost:7148",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:5174",
        "http://127.0.0.1:5174",
    ],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)
app.include_router(quality_router)
app.include_router(workflow_router)
app.include_router(tools_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ONLINE"}
