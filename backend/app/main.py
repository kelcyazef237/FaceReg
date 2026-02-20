"""FaceReg — Facial Recognition API"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from app.core.config import settings
from app.core.database import init_db
from app.api.v1.router import api_router

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s — %(message)s")
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting FaceReg API…")
    init_db()
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    yield
    logger.info("Shutting down FaceReg API…")


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    description="Facial authentication API with liveness detection",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/health", tags=["Health"])
def health():
    return {"status": "ok", "service": settings.APP_NAME}
