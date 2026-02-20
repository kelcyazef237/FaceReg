"""
Liveness detection — multi-layer anti-spoofing.

Blocks printed photos, screen-displayed photos, and video replay.

Layers:
 1. Blur check (Laplacian variance) — rejects low-quality / printouts
 2. Haar face detection — ensures a face is present
 3. LBP texture entropy — real skin micro-texture vs screen/print
 4. Moiré detection (FFT high-freq ratio) — screen pixel-grid interference
 5. Skin chrominance variance (YCrCb Cr) — flat screen vs natural skin
 6. Monocular depth estimation (MiDaS-small) — 3D face vs flat surface
 7. Inter-frame motion — catches perfectly static replay

For login (sequence), signals 3-6 use scoring: fail if ≥ 2 of 4 trigger.
"""
import cv2
import numpy as np
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)

# ── Thresholds (tuned for phone front-camera → face at ~30-60 cm) ─────────

BLUR_MIN_SINGLE = 25       # enrollment — below = too blurry
BLUR_MIN_SEQ    = 15       # per-frame in sequence — discard if below
MOTION_AVG_MIN  = 0.8      # mean pixel diff — below = static replay
LBP_ENTROPY_MIN = 4.5      # LBP histogram entropy — below = artificial texture
MOIRE_RATIO_MAX = 0.96     # FFT high-freq energy ratio — above = screen moiré (phone cameras ~0.93-0.95)
SKIN_CR_VAR_MIN = 8.0      # Cr channel variance — below = flat colour (screen)


@dataclass
class LivenessResult:
    passed: bool
    reason: str
    blur_score: float = 0.0
    motion_score: float = 0.0


# ── Low-level helpers ──────────────────────────────────────────────────────────

def _decode(image_bytes: bytes):
    return cv2.imdecode(np.frombuffer(image_bytes, np.uint8), cv2.IMREAD_COLOR)


def _blur(gray: np.ndarray) -> float:
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def _cascade():
    return cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )


def _find_face(cascade, gray):
    """Return (x, y, w, h) of largest face, or None."""
    faces = cascade.detectMultiScale(gray, 1.1, 5, minSize=(60, 60))
    if len(faces) == 0:
        return None
    return tuple(faces[int(np.argmax([w * h for (x, y, w, h) in faces]))])


# ── Anti-spoof signals ─────────────────────────────────────────────────────────

def _lbp_entropy(gray_face: np.ndarray) -> float:
    """
    Local Binary Pattern histogram entropy of the face region.
    Real skin has rich micro-texture → diverse LBP codes → high entropy.
    Screen/print reproductions have smoother / regular texture → lower entropy.
    ~3 ms on a 96×96 crop.
    """
    face = cv2.resize(gray_face, (96, 96))
    h, w = face.shape
    center = face[1:-1, 1:-1].astype(np.int16)
    lbp = np.zeros_like(center, dtype=np.uint8)
    for bit, (dy, dx) in enumerate(
        [(-1, -1), (-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1)]
    ):
        nb = face[1 + dy : h - 1 + dy, 1 + dx : w - 1 + dx].astype(np.int16)
        lbp |= ((nb >= center).astype(np.uint8) << bit)
    hist = np.bincount(lbp.ravel(), minlength=256).astype(np.float64)
    hist /= hist.sum() + 1e-10
    nz = hist[hist > 0]
    return float(-np.sum(nz * np.log2(nz)))


def _moire_ratio(gray_face: np.ndarray) -> float:
    """
    High-frequency energy ratio via 2D FFT.
    Screen photographs contain moiré patterns from camera-sensor / display-pixel
    interference, pushing energy into high-frequency bands.
    ~1 ms on a 128×128 crop.
    """
    face = cv2.resize(gray_face, (128, 128)).astype(np.float32)
    mag = np.log(np.abs(np.fft.fftshift(np.fft.fft2(face))) + 1)
    h, w = mag.shape
    Y, X = np.ogrid[:h, :w]
    dist = np.sqrt((X - w // 2) ** 2 + (Y - h // 2) ** 2)
    total = mag.sum()
    if total < 1e-10:
        return 0.0
    low = mag[dist <= 15].sum()
    return float((total - low) / total)


def _skin_cr_var(img_bgr: np.ndarray, rect: tuple) -> float:
    """
    Variance of the Cr channel in the face ROI (YCrCb space).
    Real skin has natural chrominance variation from blood flow, shadows, etc.
    Screen-reproduced faces have flatter, more uniform chrominance.
    ~0.5 ms.
    """
    x, y, fw, fh = rect
    roi = img_bgr[y : y + fh, x : x + fw]
    if roi.size == 0:
        return 100.0
    cr = cv2.cvtColor(roi, cv2.COLOR_BGR2YCrCb)[:, :, 1].astype(np.float64)
    return float(np.var(cr))


def _antispoof(img, gray, rect):
    """Run all anti-spoof signals on one frame. Returns list of (name, failed, value)."""
    x, y, fw, fh = rect
    gf = gray[y : y + fh, x : x + fw]
    if gf.shape[0] < 30 or gf.shape[1] < 30:
        return []  # face crop too small to analyse

    ent = _lbp_entropy(gf)
    moire = _moire_ratio(gf)
    cr_var = _skin_cr_var(img, rect)

    logger.info(
        "Anti-spoof signals — LBP_entropy=%.2f  moiré=%.3f  Cr_var=%.1f",
        ent, moire, cr_var,
    )

    return [
        ("texture", ent < LBP_ENTROPY_MIN, f"entropy={ent:.2f}"),
        ("screen_pattern", moire > MOIRE_RATIO_MAX, f"moiré={moire:.3f}"),
        ("flat_colour", cr_var < SKIN_CR_VAR_MIN, f"Cr_var={cr_var:.1f}"),
    ]


# ── Public API ─────────────────────────────────────────────────────────────────

def check_liveness_single(image_bytes: bytes) -> LivenessResult:
    """Single-frame check for enrollment — only verifies image quality + face presence.
    Anti-spoof is NOT run here; it's enforced during login instead."""
    img = _decode(image_bytes)
    if img is None:
        return LivenessResult(False, "Could not decode image")

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = _blur(gray)
    if blur < BLUR_MIN_SINGLE:
        return LivenessResult(
            False,
            f"Image too blurry (score={blur:.1f})",
            blur_score=blur,
        )

    cascade = _cascade()
    rect = _find_face(cascade, gray)
    if rect is None:
        return LivenessResult(False, "No face detected", blur_score=blur)

    return LivenessResult(True, "OK", blur_score=blur)


def check_liveness_sequence(frames_bytes: list[bytes]) -> LivenessResult:
    """
    Multi-frame liveness for login.
    Combines anti-spoof scoring with motion analysis.
    Total server processing: < 50 ms for 3–4 frames.
    """
    if len(frames_bytes) < 2:
        return LivenessResult(False, "Not enough frames")

    grays, imgs, blurs = [], [], []
    face_rects = []
    cascade = _cascade()

    for fb in frames_bytes:
        img = _decode(fb)
        if img is None:
            continue
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        b = _blur(gray)
        if b < BLUR_MIN_SEQ:
            continue
        grays.append(gray)
        imgs.append(img)
        blurs.append(b)
        face_rects.append(_find_face(cascade, gray))

    if len(grays) < 2:
        return LivenessResult(False, "Not enough usable frames")

    valid_faces = [r for r in face_rects if r is not None]
    if not valid_faces:
        return LivenessResult(False, "No face detected in frames")

    # ── Anti-spoof on sharpest frame ───────────────────────────────────────
    best = int(np.argmax(blurs))
    rect = face_rects[best] if face_rects[best] is not None else valid_faces[0]

    signals = _antispoof(imgs[best], grays[best], rect)

    # ── Depth check (MiDaS) on sharpest frame ─────────────────────────────
    from app.services.depth_check import check_depth
    depth_passed, d_range, d_std = check_depth(imgs[best], rect)
    if d_range > 0:  # model was available
        signals.append(("flat_depth", not depth_passed, f"range={d_range:.1f} std={d_std:.1f}"))

    fail_count = sum(1 for _, failed, _ in signals if failed)
    fail_reasons = [f"{n}({d})" for n, failed, d in signals if failed]

    if fail_count >= 2:
        return LivenessResult(
            False,
            f"Anti-spoof failed: {', '.join(fail_reasons)}",
            blur_score=float(np.mean(blurs)),
        )

    # ── Motion analysis ────────────────────────────────────────────────────
    motions = [
        float(cv2.absdiff(grays[i - 1], grays[i]).mean())
        for i in range(1, len(grays))
    ]
    avg_motion = float(np.mean(motions))

    if avg_motion < MOTION_AVG_MIN:
        return LivenessResult(
            False,
            f"Insufficient motion ({avg_motion:.3f}) — possible photo replay",
            blur_score=float(np.mean(blurs)),
            motion_score=avg_motion,
        )

    return LivenessResult(
        True,
        "OK",
        blur_score=float(np.mean(blurs)),
        motion_score=avg_motion,
    )
