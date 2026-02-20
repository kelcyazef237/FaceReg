"""
Monocular depth estimation for anti-spoofing.

Uses MiDaS-small (ONNX, ~64 MB) to estimate a relative depth map from
a single RGB frame.  A real 3D face shows significant depth variation
(nose protrudes ~2-4 cm from cheeks/ears), while a flat photo or screen
replay produces a nearly uniform depth surface.

Signal:  depth_range  = max(depth) - min(depth)  in the face ROI
         depth_std    = std(depth)                in the face ROI

Typical values (256×256 input, MiDaS-small):
  Real face:     depth_range ~ 30-80,  depth_std ~ 8-20
  Flat photo:    depth_range ~  3-12,  depth_std ~ 1-4
  Screen replay: depth_range ~  5-15,  depth_std ~ 2-5

Inference: ~60 ms on CPU  (single frame, 256×256).
"""
import os
import cv2
import numpy as np
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

_session = None
_input_name: str | None = None

MODELS_DIR = Path(__file__).resolve().parent.parent.parent / "models"
MIDAS_PATH = MODELS_DIR / "midas_small.onnx"

# Thresholds — face ROI depth statistics
DEPTH_RANGE_MIN = 15.0   # real face > 15;  flat < 12
DEPTH_STD_MIN   =  5.0   # real face > 5;   flat < 4


def _load():
    global _session, _input_name
    if _session is not None:
        return
    if not MIDAS_PATH.exists():
        logger.warning("MiDaS model not found at %s — depth check disabled", MIDAS_PATH)
        return
    import onnxruntime as ort
    _session = ort.InferenceSession(
        str(MIDAS_PATH),
        providers=["CPUExecutionProvider"],
    )
    _input_name = _session.get_inputs()[0].name
    logger.info("MiDaS-small loaded (depth anti-spoof enabled)")


def is_available() -> bool:
    _load()
    return _session is not None


def estimate_depth(img_bgr: np.ndarray) -> np.ndarray | None:
    """Run MiDaS on a BGR image and return a (H, W) relative depth map."""
    _load()
    if _session is None:
        return None

    # Preprocess: resize to 256×256, convert BGR→RGB, normalise, NCHW
    rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(rgb, (256, 256)).astype(np.float32) / 255.0
    # Standard ImageNet-ish normalisation
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std  = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    resized = (resized - mean) / std
    blob = resized.transpose(2, 0, 1)[np.newaxis]  # (1, 3, 256, 256)

    out = _session.run(None, {_input_name: blob})[0]  # (1, 256, 256)
    depth = out.squeeze()  # (256, 256)
    return depth


def check_depth(
    img_bgr: np.ndarray,
    face_rect: tuple[int, int, int, int],
) -> tuple[bool, float, float]:
    """
    Estimate depth on the full image, then analyse the face ROI.
    Checks center-vs-periphery depth gradient — a real face has the nose
    (center) closer to camera than cheeks/ears (edges).

    Returns (passed, depth_range, depth_std).
    If the model isn't available, returns (True, 0, 0) — non-blocking.
    """
    depth = estimate_depth(img_bgr)
    if depth is None:
        return True, 0.0, 0.0  # model unavailable → skip

    # Map face_rect (in original image coords) to 256×256 depth map coords
    h_orig, w_orig = img_bgr.shape[:2]
    x, y, fw, fh = face_rect
    sx, sy = 256.0 / w_orig, 256.0 / h_orig
    dx, dy = int(x * sx), int(y * sy)
    dw, dh = max(int(fw * sx), 1), max(int(fh * sy), 1)
    dx = max(dx, 0)
    dy = max(dy, 0)

    roi = depth[dy : dy + dh, dx : dx + dw]
    if roi.size < 100:
        return True, 0.0, 0.0  # ROI too small to judge

    d_range = float(roi.max() - roi.min())
    d_std   = float(roi.std())

    # Center-vs-edge gradient: nose area should be "closer" (higher depth value)
    rh, rw = roi.shape
    cy, cx = rh // 2, rw // 2
    margin_y, margin_x = max(rh // 6, 2), max(rw // 6, 2)
    center = roi[cy - margin_y : cy + margin_y, cx - margin_x : cx + margin_x]
    edge_top    = roi[:margin_y, :]
    edge_bottom = roi[-margin_y:, :]
    edge_left   = roi[:, :margin_x]
    edge_right  = roi[:, -margin_x:]
    edge_mean = np.mean([edge_top.mean(), edge_bottom.mean(),
                         edge_left.mean(), edge_right.mean()])
    center_mean = center.mean()
    gradient = abs(float(center_mean - edge_mean))

    logger.info(
        "Depth check — range=%.1f  std=%.1f  center_edge_gradient=%.1f",
        d_range, d_std, gradient,
    )

    # Either significant overall depth variation OR clear center-edge gradient
    passed = d_std >= DEPTH_STD_MIN or gradient >= DEPTH_RANGE_MIN
    return passed, d_range, d_std
