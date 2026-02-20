FROM python:3.11-slim

WORKDIR /app

# System deps for OpenCV headless
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps first (layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Download models at build time so the image is self-contained
# (skipped if models/ already contains the files — e.g. when building locally)
RUN python3 download_models.py

EXPOSE 8000

ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
