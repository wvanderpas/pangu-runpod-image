# Use the same base image you run on RunPod
FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# --- OS deps (consolidated) ---------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates git git-lfs \
    build-essential cmake make gfortran unzip \
    tzdata vim \
    libnetcdff-dev libopenjp2-7-dev \
    python3-venv python3-pip \
 && rm -rf /var/lib/apt/lists/*

# --- Build & install ecCodes 2.41.1 ------------------------------------------
WORKDIR /tmp/eccodes
RUN wget -q https://confluence.ecmwf.int/download/attachments/45757960/eccodes-2.41.1-Source.tar.gz \
 && tar -xzf eccodes-2.41.1-Source.tar.gz \
 && mkdir build && cd build \
 && cmake ../eccodes-2.41.1-Source \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DENABLE_JPG=ON \
 && make -j"$(nproc)" \
 # ctest can be slow/flaky in CI → you can enable if you want
 # && ctest --output-on-failure \
 && make install \
 && ldconfig \
 && cd / && rm -rf /tmp/eccodes

# --- Python env in the image --------------------------------------------------
RUN python3 -m venv /opt/pangu-venv \
 && /opt/pangu-venv/bin/pip install --upgrade pip setuptools wheel \
 && /opt/pangu-venv/bin/pip install --no-cache-dir \
      "onnxruntime-gpu[cuda,cudnn]" \
      ai-models ai-models-panguweather ai-models-panguweather-gfs \
      matplotlib basemap

# --- Runtime helper to activate env + fix LD_LIBRARY_PATH ---------------------
RUN cat >/usr/local/bin/activate_pangu.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
source /opt/pangu-venv/bin/activate
# Discover ONNXRuntime-bundled NVIDIA libs (cudnn/cublas etc.)
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

# --- Default workdir ----------------------------------------------------------
WORKDIR /workspace
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
