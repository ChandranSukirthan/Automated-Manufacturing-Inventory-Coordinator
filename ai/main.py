from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from ai.routes.quality_routes import router as quality_router


app = FastAPI(title="AMIC AI Service")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=False,
    allow_methods=["POST", "GET"],
    allow_headers=["Content-Type", "Authorization"],
)
app.include_router(quality_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
