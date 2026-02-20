from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class UserOut(BaseModel):
    id: int
    name: str
    phone_number: str
    face_enrolled: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class FaceVerifyResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    similarity: float
    liveness_passed: bool
    user: UserOut


class RefreshRequest(BaseModel):
    refresh_token: str


class MessageResponse(BaseModel):
    message: str
