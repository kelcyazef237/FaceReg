#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# FaceReg backend — bare-metal startup script
# Usage:  bash run.sh          (foreground)
#         bash run.sh --daemon  (background via nohup)
# ---------------------------------------------------------------------------
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Virtualenv — create if missing, always activate ───────────────────────
if [ ! -d ".venv" ]; then
  echo "Creating virtualenv…"
  python3 -m venv .venv
fi
source .venv/bin/activate

# ── Copy sample env if .env missing ────────────────────────────────────────
if [ ! -f ".env" ]; then
  echo "No .env found — copying .env.example → .env"
  cp .env.example .env
  # Auto-generate secret keys
  SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  REFRESH=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  sed -i "s/change_me_run_openssl_rand_hex_32/$SECRET/" .env
  sed -i "s/change_me_refresh_run_openssl_rand_hex_32/$REFRESH/" .env
  echo "✅ .env created with auto-generated secret keys"
fi

# ── Install / upgrade deps ─────────────────────────────────────────────────
echo "Installing dependencies…"
pip install --quiet --upgrade pip
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

