# Smaller base to avoid CI disk limits (no PyTorch baked in)
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# --- OS & build deps ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates git git-lfs \
    build-essential cmake make gfortran unzip \
    tzdata vim \
    libnetcdff-dev libopenjp2-7-dev \
    zlib1g-dev libpng-dev \
    python3-venv python3-pip \
    openssh-server tini \
 && rm -rf /var/lib/apt/lists/*

# --- Build & install ecCodes 2.41.1 -----------------------------------------
WORKDIR /tmp
RUN git clone --branch 2.41.1 --depth 1 https://github.com/ecmwf/eccodes.git \
 && mkdir -p eccodes/build && cd eccodes/build \
 && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_JPG=ON \
 && make -j"$(nproc)" && make install && ldconfig \
 && cd / && rm -rf /tmp/eccodes

# --- Python env --------------------------------------------------------------
RUN python3 -m venv /opt/pangu-venv \
 && /opt/pangu-venv/bin/pip install --upgrade pip setuptools wheel \
 && /opt/pangu-venv/bin/pip install --no-cache-dir \
      "onnxruntime-gpu[cuda,cudnn]" \
      ai-models ai-models-panguweather ai-models-panguweather-gfs \
      matplotlib basemap

# --- Runtime helper ----------------------------------------------------------
RUN cat >/usr/local/bin/activate_pangu.sh <<'SH'
#!/usr/bin/env bash
# Activate the baked venv
source /opt/pangu-venv/bin/activate
# Export ORT CUDA libs into LD_LIBRARY_PATH
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
RUN chmod +x /usr/local/bin/activate_pangu.sh \
 && echo 'source /usr/local/bin/activate_pangu.sh' >/etc/profile.d/pangu.sh

# --- SSH setup ---------------------------------------------------------------
# Create a non-root user for SSH; prepare sshd runtime dir
RUN useradd -m -s /bin/bash runpod \
 && mkdir -p /home/runpod/.ssh /var/run/sshd \
 && chmod 700 /home/runpod/.ssh \
 && chown -R runpod:runpod /home/runpod/.ssh \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# If you want to bake a key at build time, uncomment and provide it:
# COPY id_ed25519.pub /tmp/id.pub
# RUN cat /tmp/id.pub >> /home/runpod/.ssh/authorized_keys \
#  && chmod 600 /home/runpod/.ssh/authorized_keys \
#  && chown runpod:runpod /home/runpod/.ssh/authorized_keys

WORKDIR /workspace
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

EXPOSE 22

# Keep container alive and serve SSH (tini = proper PID 1 + signal handling)
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/sbin/sshd","-D"]
