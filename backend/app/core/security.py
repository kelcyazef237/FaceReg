from datetime import datetime, timedelta, timezone
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.config import settings
from app.core.database import get_db

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer_scheme = HTTPBearer()


# ── Password ──────────────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ── JWT ───────────────────────────────────────────────────────────────────────

def _create_token(data: dict, secret: str, expire_delta: timedelta) -> str:
    payload = data.copy()
    payload["exp"] = datetime.now(timezone.utc) + expire_delta
    return jwt.encode(payload, secret, algorithm=settings.ALGORITHM)


def create_access_token(user_id: int) -> str:
    return _create_token(
        {"sub": str(user_id), "type": "access"},
        settings.SECRET_KEY,
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    )


def create_refresh_token(user_id: int) -> str:
    return _create_token(
        {"sub": str(user_id), "type": "refresh"},
        settings.REFRESH_SECRET_KEY,
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )


def decode_access_token(token: str) -> Optional[int]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        if payload.get("type") != "access":
            return None
        return int(payload["sub"])
    except JWTError:
        return None


def decode_refresh_token(token: str) -> Optional[int]:
    try:
        payload = jwt.decode(token, settings.REFRESH_SECRET_KEY, algorithms=[settings.ALGORITHM])
        if payload.get("type") != "refresh":
            return None
        return int(payload["sub"])
    except JWTError:
        return None


# ── Dependency ────────────────────────────────────────────────────────────────

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
):
    from app.models.user import User

    user_id = decode_access_token(credentials.credentials)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user
