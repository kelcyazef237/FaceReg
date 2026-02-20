"""
Downloads and caches the face recognition models on first use.

Models:
  YuNet face detector  — 228 KB  (face_detection_yunet.onnx)
  SFace face recognizer — 37 MB   (face_recognition_sface.onnx)

Both from the official OpenCV model zoo (reliable GitHub LFS).
Run standalone: python3 download_models.py
"""
import logging
import urllib.request
from pathlib import Path

logger = logging.getLogger(__name__)

MODELS_DIR = Path(__file__).parent.parent.parent / "models"

MODELS = [
    {
        "name": "face_detection_yunet.onnx",
        "url": (
            "https://media.githubusercontent.com/media/opencv/opencv_zoo/main"
            "/models/face_detection_yunet/face_detection_yunet_2023mar.onnx"
        ),
        "desc": "YuNet face detector (228 KB)",
    },
    {
        "name": "face_recognition_sface.onnx",
        "url": (
            "https://media.githubusercontent.com/media/opencv/opencv_zoo/main"
            "/models/face_recognition_sface/face_recognition_sface_2021dec.onnx"
        ),
        "desc": "SFace face recognizer (37 MB)",
    },
    {
        "name": "midas_small.onnx",
        "url": (
            "https://github.com/isl-org/MiDaS/releases/download/v2_1"
            "/model-small.onnx"
        ),
        "desc": "MiDaS-small depth estimator (64 MB)",
    },
]


def ensure_models() -> None:
    """Download any missing models. No-op if both exist."""
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    for m in MODELS:
        path = MODELS_DIR / m["name"]
        if path.exists() and path.stat().st_size > 10_000:
            logger.info("Model present: %s", m["name"])
            continue
        logger.info("Downloading %s from %s …", m["desc"], m["url"])
        try:
            _download(m["url"], path)
            logger.info("✅  %s  (%.1f MB)", m["name"], path.stat().st_size / 1e6)
        except Exception as e:
            if path.exists():
                path.unlink()
            raise RuntimeError(f"Failed to download {m['name']}: {e}") from e


def _download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "FaceReg/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        total = int(resp.headers.get("Content-Length", 0))
        downloaded = 0
        with open(dest, "wb") as f:
            while chunk := resp.read(65536):
                f.write(chunk)
                downloaded += len(chunk)
                if total:
                    print(
                        f"\r  {downloaded / total * 100:.0f}%  "
                        f"({downloaded // 1024} / {total // 1024} KB)",
                        end="", flush=True,
                    )
    print()
