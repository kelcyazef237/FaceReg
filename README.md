# FaceReg

Facial recognition authentication system — FastAPI backend + Flutter mobile app.

- **Face-only auth** — no passwords, no PINs
- **YuNet + SFace** (OpenCV) for face detection and 128-d embedding extraction
- **MiDaS-small** depth estimation for anti-spoofing
- **Apple Face ID–style** automatic re-authentication on app open
- **Adaptive embeddings** — updates gradually on each successful login

---

## Architecture

```
frontend/   Flutter app (Android/iOS)
backend/    FastAPI + SQLite + OpenCV face recognition
```

---

## Quick Start — Docker (recommended for AWS)

### Prerequisites
- Docker + Docker Compose installed on the server
- Ports 8000 open in your security group / firewall

```bash
git clone https://github.com/kelcyazef/FaceReg.git
cd FaceReg

# 1. Set secrets
cp backend/.env.example backend/.env
# Edit backend/.env — set SECRET_KEY and REFRESH_SECRET_KEY:
#   openssl rand -hex 32   ← run this twice for the two keys

# 2. Build and start (models download automatically during build, ~100 MB)
docker compose up --build -d

# 3. Check it's running
curl http://localhost:8000/health
```

Logs: `docker compose logs -f`  
Stop: `docker compose down`

---

## Quick Start — Bare Metal (no Docker)

```bash
# Requires Python 3.11+
cd backend

python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt

cp .env.example .env
# Edit .env — generate keys with: openssl rand -hex 32

# Download face models (~100 MB total, one-time)
python3 download_models.py

# Start (foreground)
bash run.sh

# OR start as background daemon
bash run.sh --daemon
# Logs go to backend/facereg.log
```

---

## AWS EC2 Deployment

Tested on Ubuntu 22.04 / Amazon Linux 2023.

```bash
# 1. Install Docker
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER && newgrp docker

# 2. Clone repo
git clone https://github.com/kelcyazef/FaceReg.git
cd FaceReg

# 3. Configure secrets
cp backend/.env.example backend/.env
nano backend/.env          # set SECRET_KEY + REFRESH_SECRET_KEY

# 4. Start (first run downloads models — takes ~2 min depending on connection)
docker compose up --build -d

# 5. Verify
curl http://<your-ec2-public-ip>:8000/health
# → {"status":"ok","models_loaded":true}
```

**Security group**: open inbound TCP 8000 (or put nginx in front on port 80/443).

### systemd service (auto-restart on reboot)

```bash
sudo tee /etc/systemd/system/facereg.service << 'EOF'
[Unit]
Description=FaceReg API
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/home/ubuntu/FaceReg
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=on-failure
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable facereg
sudo systemctl start facereg
```

---

## API Reference

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/register-face` | Register with name, phone + face image |
| POST | `/api/v1/auth/login/face` | Login with name + 3 face frames |
| POST | `/api/v1/auth/token/refresh` | Refresh JWT tokens |
| GET  | `/api/v1/auth/me` | Get current user profile |
| DELETE | `/api/v1/auth/admin/clear` | Wipe database (dev/admin) |
| GET  | `/health` | Health check |

---

## Flutter App Configuration

The server IP/port can be changed **inside the app**:  
Settings ⚙️ (top-right on any auth screen or home screen) → **SERVER** section.

Default: `13.53.154.169:8000`

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY` | *(change me)* | JWT signing key — generate with `openssl rand -hex 32` |
| `REFRESH_SECRET_KEY` | *(change me)* | Refresh token signing key |
| `DATABASE_URL` | `sqlite:///./facereg.db` | SQLAlchemy database URL |
| `SIMILARITY_THRESHOLD` | `0.593` | Face match threshold (0–1) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `15` | Access token lifetime |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `7` | Refresh token lifetime |
| `MAX_UPLOAD_MB` | `10` | Max image upload size |
| `DEBUG` | `false` | Enable debug mode |

---

## Models

Downloaded automatically on first startup. Stored in `backend/models/`:

| Model | Size | Purpose |
|-------|------|---------|
| `face_detection_yunet.onnx` | 228 KB | Face detection + alignment |
| `face_recognition_sface.onnx` | 37 MB | Face embedding extraction |
| `midas_small.onnx` | 64 MB | Depth-based anti-spoofing |
