# Base with CUDA + cuDNN
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# --- OS & build deps (no ssh/jupyter/nginx) ---------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates git git-lfs \
    build-essential cmake make gfortran unzip \
    tzdata vim tini \
    libnetcdff-dev libopenjp2-7-dev \
    zlib1g-dev libpng-dev \
    python3-venv python3-pip \
 && rm -rf /var/lib/apt/lists/*

# --- Build & install ecCodes 2.41.1 -----------------------------------------
WORKDIR /tmp
RUN git clone --branch 2.41.1 --depth 1 https://github.com/ecmwf/eccodes.git \
 && mkdir -p eccodes/build && cd eccodes/build \
 && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_JPG=ON \
 && make -j"$(nproc)" && make install && ldconfig \
 && cd / && rm -rf /tmp/eccodes

# --- Python venv + packages --------------------------------------------------
RUN python3 -m venv /opt/pangu-venv \
 && /opt/pangu-venv/bin/pip install --upgrade pip setuptools wheel \
 && /opt/pangu-venv/bin/pip install --no-cache-dir \
      "onnxruntime-gpu[cuda,cudnn]" \
      ai-models ai-models-panguweather ai-models-panguweather-gfs \
      matplotlib basemap basemap-data-hires 


# --- Runtime helper: activate env & LD_LIBRARY_PATH for ONNX Runtime ---------
RUN <<'BASH'
set -eux
cat >/usr/local/bin/activate_pangu.sh <<'SH'
#!/usr/bin/env bash
# Activate the baked venv
source /opt/pangu-venv/bin/activate
# Discover ONNX Runtime–bundled NVIDIA libs and export
NVIDIA_LIBS_DIRS="$(python - <<'PY'
import site,glob,os
sp = site.getsitepackages()[0]
dirs=[d for d in glob.glob(os.path.join(sp,'nvidia','*','lib')) if os.path.isdir(d)]
print(':'.join(dirs))
PY
)"
export LD_LIBRARY_PATH="${NVIDIA_LIBS_DIRS}:${LD_LIBRARY_PATH:-}"
echo "[activate_pangu] Pangu environment ready."
SH
chmod +x /usr/local/bin/activate_pangu.sh
echo 'source /usr/local/bin/activate_pangu.sh' >/etc/profile.d/pangu.sh
BASH

# --- Non-root user & workspace dir ------------------------------------------
RUN useradd -m -s /bin/bash runpod && \
    mkdir -p /workspace && chown -R runpod:runpod /workspace

# --- Boot script: wait for /workspace script, then exec as main -------------
RUN <<'BASH'
set -eux
cat > /usr/local/bin/runpod-start.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT="/workspace/scripts/pangu-gfs-latest.sh"

# Ensure workspace exists (RunPod network volume usually mounts here)
mkdir -p /workspace || true
chown runpod:runpod /workspace || true

# Brief wait loop in case the network volume mounts just after container start
echo "[startup] Waiting for ${SCRIPT} to appear..."
for i in {1..60}; do
  if [[ -f "$SCRIPT" ]]; then
    break
  fi
  sleep 1
done

if [[ ! -f "$SCRIPT" ]]; then
  echo "[startup][FATAL] ${SCRIPT} not found after waiting. Exiting."
  exit 1
fi

# Ensure it’s executable
chmod +x "$SCRIPT" || true

# Activate venv + ONNX libs and exec as 'runpod' so it becomes the main process
exec runuser -u runpod -- bash -lc "source /usr/local/bin/activate_pangu.sh 2>/dev/null || true; exec \"$SCRIPT\""
SH
chmod +x /usr/local/bin/runpod-start.sh
BASH

# --- Defaults ---------------------------------------------------------------
WORKDIR /workspace
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# No ports exposed; batch job only
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/local/bin/runpod-start.sh"]
