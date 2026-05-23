"""FastAPI application for the Quantum-Inspired Optimization Accelerator."""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .api.routes import router
from .api.websocket import ws_router

app = FastAPI(
    title="Quantum Annealing Accelerator",
    description="Backend for quantum-inspired optimization simulation and RTL analysis",
    version="0.1.0",
)

# CORS middleware (allow all origins for development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(router)
app.include_router(ws_router)


@app.get("/api/health")
async def health_check() -> dict:
    """Health check endpoint."""
    return {"status": "ok", "service": "quantum-annealing-accelerator"}


# Static file serving for frontend build
frontend_build = Path(__file__).resolve().parent.parent / "frontend" / "build"
if frontend_build.exists():
    app.mount("/", StaticFiles(directory=str(frontend_build), html=True), name="frontend")
