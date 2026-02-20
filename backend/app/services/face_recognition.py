"""
Face recognition service — OpenCV YuNet + SFace (no TensorFlow needed).

Pipeline:
  image bytes → YuNet face detection + 5-point alignment
             → SFace ONNX embedding (128-d, L2-normalised)
             → cosine similarity → match / adaptive update

Models (~37 MB total, bundled in backend/models/):
  face_detection_yunet.onnx  — YuNet detector (228 KB)
  face_recognition_sface.onnx — SFace recognizer (37 MB)
"""
import cv2
import numpy as np
import logging
import threading
from pathlib import Path
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)

MODELS_DIR = Path(__file__).parent.parent.parent / "models"
YUNET_PATH  = MODELS_DIR / "face_detection_yunet.onnx"
SFACE_PATH  = MODELS_DIR / "face_recognition_sface.onnx"

# ── Thread-safe lazy singletons ────────────────────────────────────────────────

_lock     = threading.Lock()
_detector = None   # cv2.FaceDetectorYN
_recognizer = None # cv2.FaceRecognizerSF


def _get_models():
    global _detector, _recognizer
    if _detector is not None:
        return _detector, _recognizer

    with _lock:
        if _detector is not None:
            return _detector, _recognizer

        if not YUNET_PATH.exists():
            raise RuntimeError(
                f"YuNet model not found at {YUNET_PATH}.\n"
                "Run: python3 download_models.py"
            )
        if not SFACE_PATH.exists():
            raise RuntimeError(
                f"SFace model not found at {SFACE_PATH}.\n"
                "Run: python3 download_models.py"
            )

        det = cv2.FaceDetectorYN.create(
            str(YUNET_PATH),
            "",
            (320, 320),
            score_threshold=0.6,
            nms_threshold=0.3,
            top_k=1,
        )
        rec = cv2.FaceRecognizerSF.create(str(SFACE_PATH), "")

        _detector = det
        _recognizer = rec
        logger.info("YuNet + SFace models loaded from %s", MODELS_DIR)
        return _detector, _recognizer


# ── Internal helpers ───────────────────────────────────────────────────────────

def _detect_and_align(detector, recognizer, img: np.ndarray) -> Optional[np.ndarray]:
    """
    Detect the largest face with YuNet and return the aligned 112×112 crop
    as expected by SFace. Returns None if no face is found.
    """
    h, w = img.shape[:2]
    detector.setInputSize((w, h))

    _, faces = detector.detect(img)
    if faces is None or len(faces) == 0:
        return None

    # Use face with highest confidence
    face = faces[np.argmax(faces[:, -1])]

    aligned = recognizer.alignCrop(img, face)  # returns (112, 112, 3) uint8
    return aligned


# ── Public API ─────────────────────────────────────────────────────────────────

def extract_embedding(image_bytes: bytes) -> Optional[list[float]]:
    """
    Extract SFace embedding from raw image bytes.
    Returns L2-normalised 128-d vector, or None if no face detected.
    """
    try:
        detector, recognizer = _get_models()
    except RuntimeError as e:
        logger.error("Model load error: %s", e)
        return None

    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return None

    aligned = _detect_and_align(detector, recognizer, img)
    if aligned is None:
        logger.debug("No face detected in image")
        return None

    embedding = recognizer.feature(aligned)          # (1, 128) float32
    embedding = embedding.flatten()                   # (128,)
    norm = np.linalg.norm(embedding)
    if norm > 0:
        embedding = embedding / norm
    return embedding.tolist()


def verify_face(
    new_embedding: list[float],
    stored_embedding: list[float],
) -> tuple[bool, float]:
    """Returns (is_match, cosine_similarity ∈ [-1, 1])."""
    va = np.array(new_embedding)
    vb = np.array(stored_embedding)
    # Both L2-normalised → dot = cosine similarity
    sim = float(np.dot(va, vb))
    return sim >= settings.SIMILARITY_THRESHOLD, sim


def adaptive_update(
    stored_embedding: list[float],
    new_embedding: list[float],
    alpha: float | None = None,
) -> list[float]:
    """Blend new embedding into stored with weight alpha (default 5%)."""
    if alpha is None:
        alpha = settings.ADAPTIVE_ALPHA
    updated = (1 - alpha) * np.array(stored_embedding) + alpha * np.array(new_embedding)
    updated /= np.linalg.norm(updated)
    return updated.tolist()
