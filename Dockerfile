# Base with CUDA + cuDNN
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# --- OS & build deps ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates git git-lfs \
    build-essential cmake make gfortran unzip \
    tzdata vim tini \
    libnetcdff-dev libopenjp2-7-dev \
    zlib1g-dev libpng-dev \
    python3-venv python3-pip \
    openssh-server nginx \
 && rm -rf /var/lib/apt/lists/*

# --- Build & install ecCodes 2.41.1 -----------------------------------------
WORKDIR /tmp
RUN git clone --branch 2.41.1 --depth 1 https://github.com/ecmwf/eccodes.git \
 && mkdir -p eccodes/build && cd eccodes/build \
 && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_JPG=ON \
 && make -j"$(nproc)" && make install && ldconfig \
 && cd / && rm -rf /tmp/eccodes

# --- Python venv + packages (install Jupyter into the venv) ------------------
RUN python3 -m venv /opt/pangu-venv \
 && /opt/pangu-venv/bin/pip install --upgrade pip setuptools wheel \
 && /opt/pangu-venv/bin/pip install --no-cache-dir \
      "onnxruntime-gpu[cuda,cudnn]" \
      ai-models ai-models-panguweather ai-models-panguweather-gfs \
      matplotlib basemap jupyterlab

# --- Runtime helper: activate env & set LD_LIBRARY_PATH ----------------------
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

# --- SSH user and server -----------------------------------------------------
RUN <<'BASH'
set -eux
useradd -m -s /bin/bash runpod
mkdir -p /home/runpod/.ssh /var/run/sshd
chmod 700 /home/runpod/.ssh
chown -R runpod:runpod /home/runpod/.ssh
# Hardened sshd defaults: key-only login, no root password login
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
BASH

# --- nginx: proxy HTTP :80 -> Jupyter :8888 ----------------------------------
RUN <<'BASH'
set -eux
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
cat > /etc/nginx/sites-available/jupyter.conf <<'NG'
server {
  listen 80;
  server_name _;
  location / {
    proxy_pass http://127.0.0.1:8888;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
  }
}
NG
rm -f /etc/nginx/sites-enabled/default || true
ln -sf /etc/nginx/sites-available/jupyter.conf /etc/nginx/sites-enabled/jupyter.conf
BASH

# --- Boot script: inject PUBLIC_KEY, set Jupyter, start services -------------
RUN <<'BASH'
set -eux
cat > /usr/local/bin/runpod-start.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# 1) SSH key injection (optional via env PUBLIC_KEY)
if [[ -n "${PUBLIC_KEY:-}" ]]; then
  install -d -m 700 -o runpod -g runpod /home/runpod/.ssh
  if ! grep -qF "$PUBLIC_KEY" /home/runpod/.ssh/authorized_keys 2>/dev/null; then
    echo "$PUBLIC_KEY" >> /home/runpod/.ssh/authorized_keys
  fi
  chown runpod:runpod /home/runpod/.ssh/authorized_keys
  chmod 600 /home/runpod/.ssh/authorized_keys
fi

# 2) Jupyter auth & options (use token to avoid hashing complexity)
JUPYTER_ARGS=(--ServerApp.ip=0.0.0.0 --ServerApp.port=8888 --ServerApp.allow_origin=* \
              --ServerApp.root_dir=/workspace --ServerApp.allow_remote_access=True --ServerApp.open_browser=False)
if [[ -n "${JUPYTER_TOKEN:-}" ]]; then
  JUPYTER_ARGS+=(--ServerApp.token="${JUPYTER_TOKEN}")
else
  # tokenless; set JUPYTER_TOKEN in template to require one
  JUPYTER_ARGS+=(--ServerApp.token=)
fi

# 3) Start services
/usr/sbin/sshd
# Jupyter under 'runpod' user (activate venv, then launch Jupyter from venv)
runuser -u runpod -- bash -lc "mkdir -p /workspace; source /usr/local/bin/activate_pangu.sh 2>/dev/null || true; /opt/pangu-venv/bin/jupyter lab ${JUPYTER_ARGS[*]}" &

# nginx in foreground keeps the container alive
exec nginx -g 'daemon off;'
SH
chmod +x /usr/local/bin/runpod-start.sh
BASH

# --- Defaults ---------------------------------------------------------------
WORKDIR /workspace
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

EXPOSE 22 80
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/local/bin/runpod-start.sh"]
