"""Auth endpoints — face-only registration, face login, token refresh, profile."""
import logging
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import (
    create_access_token, create_refresh_token,
    decode_refresh_token, get_current_user,
)
from app.core.config import settings
from app.models.user import User, AuthAttempt
from app.schemas.user import (
    UserOut, TokenPair, FaceVerifyResponse, RefreshRequest, MessageResponse,
)
from app.services import face_recognition as fr
from app.services import liveness as lv

logger = logging.getLogger(__name__)
router = APIRouter()


# ── Register with face ────────────────────────────────────────────────────────

@router.post("/register-face", response_model=FaceVerifyResponse, status_code=201)
async def register_face(
    name: str = Form(...),
    phone_number: str = Form(...),
    face_image: UploadFile = File(..., description="JPEG/PNG of the face"),
    db: Session = Depends(get_db),
):
    name = name.strip()
    phone_number = phone_number.strip()

    if len(name) < 2 or len(name) > 100:
        raise HTTPException(status_code=422, detail="Name must be 2–100 characters")
    if len(phone_number) < 6:
        raise HTTPException(status_code=422, detail="Invalid phone number")
    if db.query(User).filter(User.name == name).first():
        raise HTTPException(status_code=409, detail="Name already taken")

    img_bytes = await face_image.read()
    if len(img_bytes) > settings.MAX_UPLOAD_MB * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image too large")

    live = lv.check_liveness_single(img_bytes)
    if not live.passed:
        raise HTTPException(status_code=422, detail=f"Liveness failed: {live.reason}")

    embedding = fr.extract_embedding(img_bytes)
    if embedding is None:
        raise HTTPException(status_code=422, detail="No face detected in image")

    user = User(
        name=name,
        phone_number=phone_number,
        face_embedding=embedding,
        face_enrolled=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return FaceVerifyResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        similarity=1.0,
        liveness_passed=True,
        user=UserOut.model_validate(user),
    )


# ── Face login ────────────────────────────────────────────────────────────────

@router.post("/login/face", response_model=FaceVerifyResponse)
async def login_face(
    request: Request,
    name: str = Form(...),
    face_frames: list[UploadFile] = File(..., description="Sequential JPEG frames"),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.name == name).first()
    if not user or not user.face_enrolled or user.face_embedding is None:
        _log_attempt(db, None, False, None, False, request)
        raise HTTPException(status_code=401, detail="Invalid credentials")

    frames_bytes = [await f.read() for f in face_frames]

    live_result = lv.check_liveness_sequence(frames_bytes)
    if not live_result.passed:
        _log_attempt(db, user.id, False, None, False, request)
        raise HTTPException(
            status_code=401,
            detail=f"Liveness failed: {live_result.reason}",
        )

    mid_frame = frames_bytes[len(frames_bytes) // 2]
    new_embedding = fr.extract_embedding(mid_frame)
    if new_embedding is None:
        _log_attempt(db, user.id, False, None, True, request)
        raise HTTPException(status_code=422, detail="Could not detect face in frames")

    is_match, similarity = fr.verify_face(new_embedding, user.face_embedding)
    _log_attempt(db, user.id, is_match, similarity, True, request)

    if not is_match:
        raise HTTPException(status_code=401, detail="Face does not match")

    # Adaptive embedding update
    user.face_embedding = fr.adaptive_update(user.face_embedding, new_embedding)
    db.commit()

    return FaceVerifyResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        similarity=round(similarity, 4),
        liveness_passed=True,
        user=UserOut.model_validate(user),
    )


# ── Token refresh ─────────────────────────────────────────────────────────────

@router.post("/token/refresh", response_model=TokenPair)
def refresh_tokens(body: RefreshRequest, db: Session = Depends(get_db)):
    user_id = decode_refresh_token(body.refresh_token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
    user = db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found")
    return TokenPair(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


# ── Profile ───────────────────────────────────────────────────────────────────

@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


# ── Admin: clear database ─────────────────────────────────────────────────────

@router.delete("/admin/clear", status_code=200)
def clear_database(db: Session = Depends(get_db)):
    """Delete all users and auth attempts. Dev/admin use only."""
    db.query(AuthAttempt).delete()
    db.query(User).delete()
    db.commit()
    logger.warning("Database cleared via admin endpoint")
    return {"detail": "Database cleared"}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _log_attempt(db, user_id, success, similarity, liveness_passed, request):
    ip = request.client.host if request.client else None
    db.add(AuthAttempt(
        user_id=user_id,
        success=success,
        similarity_score=str(round(similarity, 4)) if similarity is not None else None,
        liveness_passed=liveness_passed,
        ip_address=ip,
    ))
    db.commit()
