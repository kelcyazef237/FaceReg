from app.core.database import Base
from sqlalchemy import Column, Integer, String, Boolean, DateTime, JSON
from datetime import datetime, timezone


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, index=True, nullable=False)
    phone_number = Column(String(20), nullable=False)
    face_embedding = Column(JSON, nullable=True)
    face_enrolled = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc))


class AuthAttempt(Base):
    __tablename__ = "auth_attempts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)
    success = Column(Boolean, nullable=False)
    similarity_score = Column(String(10), nullable=True)
    liveness_passed = Column(Boolean, nullable=True)
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
