# Smaller base to avoid CI disk limits (no PyTorch baked in)
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# --- OS & build deps (consolidated) ------------------------------------------
# Add zlib/libpng dev headers needed by ecCodes; keep image tidy.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates git git-lfs \
    build-essential cmake make gfortran unzip \
    tzdata vim \
    libnetcdff-dev libopenjp2-7-dev \
    zlib1g-dev libpng-dev \
    python3-venv python3-pip \
 && rm -rf /var/lib/apt/lists/*

# --- Build & install ecCodes 2.41.1 (from GitHub tag) ------------------------
WORKDIR /tmp
RUN git clone --branch 2.41.1 --depth 1 https://github.com/ecmwf/eccodes.git \
 && mkdir -p eccodes/build && cd eccodes/build \
 && cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DENABLE_JPG=ON \
 && make -j"$(nproc)" \
 # tests are optional; uncomment if you want them:
 # && ctest --output-on-failure \
 && make install \
 && ldconfig \
 && cd / && rm -rf /tmp/eccodes

# --- Python env baked into the image -----------------------------------------
RUN python3 -m venv /opt/pangu-venv \
 && /opt/pangu-venv/bin/pip install --upgrade pip setuptools wheel \
 && /opt/pangu-venv/bin/pip install --no-cache-dir \
      "onnxruntime-gpu[cuda,cudnn]" \
      ai-models ai-models-panguweather ai-models-panguweather-gfs \
      matplotlib basemap

# --- Runtime helper: activate env + set LD_LIBRARY_PATH for ORT CUDA ---------
RUN cat >/usr/local/bin/activate_pangu.sh <<'SH'
#!/usr/bin/env bash
# set -euo pipefail   this should go for easier ssh
# Activate the baked venv
source /opt/pangu-venv/bin/activate
# Discover ONNX Runtime–bundled NVIDIA libs (cudnn/cublas etc.) and export
NVIDIA_LIBS_DIRS="$(python - <<'PY'
import site,glob,os
sp = site.getsitepackages()[0]
dirs=[d for d in glob.glob(os.path.join(sp,'nvidia','*','lib')) if os.path.isdir(d)]
print(':'.join(dirs))
PY
)"
export LD_LIBRARY_PATH="${NVIDIA_LIBS_DIRS}:${LD_LIBRARY_PATH:-}"
echo "[activate_pangu] LD_LIBRARY_PATH set for ONNX Runtime CUDA EP."
python - <<'PY' || true
import onnxruntime as ort
print("[activate_pangu] Providers:", ort.get_available_providers())
PY
echo "[activate_pangu] Pangu environment ready."
SH
RUN chmod +x /usr/local/bin/activate_pangu.sh

# --- Defaults ---------------------------------------------------------------
WORKDIR /workspace
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# No ENTRYPOINT/CMD: RunPod will manage; in the pod run:
#   source /usr/local/bin/activate_pangu.sh
