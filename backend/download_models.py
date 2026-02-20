#!/usr/bin/env python3
"""
One-time setup — download face recognition models.
Run from backend/ directory:
    python3 download_models.py
"""
import sys, logging
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")

from app.services.model_loader import ensure_models, MODELS_DIR, MODELS

if __name__ == "__main__":
    try:
        ensure_models()
        print("\n✅ All models ready:")
        for m in MODELS:
            p = MODELS_DIR / m["name"]
            print(f"   {m['name']:45s} {p.stat().st_size / 1e6:6.1f} MB")
    except RuntimeError as e:
        print(f"\n❌ {e}")
        sys.exit(1)
