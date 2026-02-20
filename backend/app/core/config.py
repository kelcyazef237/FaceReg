from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    APP_NAME: str = "FaceReg API"
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = False

    # JWT
    SECRET_KEY: str = "CHANGE_ME_IN_PRODUCTION_USE_OPENSSL_RAND_HEX_32"
    REFRESH_SECRET_KEY: str = "CHANGE_ME_REFRESH_SECRET_USE_OPENSSL_RAND_HEX_32"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ALGORITHM: str = "HS256"

    # Database
    DATABASE_URL: str = "sqlite:///./facereg.db"

    # Face recognition — OpenCV YuNet + SFace
    # SFace cosine similarity: same person ≥ 0.593 (OpenCV recommended threshold)
    SIMILARITY_THRESHOLD: float = 0.593
    ADAPTIVE_ALPHA: float = 0.05         # Embedding update blend weight

    # Uploads
    UPLOAD_DIR: str = "./uploads"
    MAX_UPLOAD_MB: int = 10

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
