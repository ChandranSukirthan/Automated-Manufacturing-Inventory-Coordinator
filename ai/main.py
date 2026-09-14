from fastapi import FastAPI

from ai.routes.quality_routes import router as quality_router


app = FastAPI(title="AMIC AI Service")
app.include_router(quality_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
