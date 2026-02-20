#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# FaceReg backend — bare-metal startup script
# Usage:  bash run.sh          (foreground)
#         bash run.sh --daemon  (background via nohup)
# ---------------------------------------------------------------------------
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Virtualenv (optional but recommended) ──────────────────────────────────
if [ -d ".venv" ]; then
  echo "Activating .venv …"
  source .venv/bin/activate
fi

# ── Copy sample env if .env missing ────────────────────────────────────────
if [ ! -f ".env" ]; then
  echo "No .env found — copying .env.example → .env"
  cp .env.example .env
  echo "⚠  Edit .env and set SECRET_KEY / REFRESH_SECRET_KEY before production use"
fi

# ── Install / upgrade deps ─────────────────────────────────────────────────
pip install --quiet -r requirements.txt

# ── Download models if missing ─────────────────────────────────────────────
python3 download_models.py

# ── Start server ───────────────────────────────────────────────────────────
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
WORKERS="${WORKERS:-1}"

if [ "$1" = "--daemon" ]; then
  echo "Starting FaceReg API in background (log → facereg.log) …"
  nohup uvicorn app.main:app \
    --host "$HOST" --port "$PORT" --workers "$WORKERS" \
    >> facereg.log 2>&1 &
  echo "PID $! — tail -f facereg.log to follow logs"
else
  echo "Starting FaceReg API on $HOST:$PORT …"
  exec uvicorn app.main:app \
    --host "$HOST" --port "$PORT" --workers "$WORKERS"
fi

