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

# --- Python env --------------------------------------------------------------
RUN python3 -m venv /opt/pangu-venv \
 && /opt/pangu-venv/bin/pip install --upgrade pip setuptools wheel \
 && /opt/pangu-venv/bin/pip install --no-cache-dir \
      "onnxruntime-gpu[cuda,cudnn]" \
      ai-models ai-models-panguweather ai-models-panguweather-gfs \
      matplotlib basemap \
 && python3 -m pip install --no-cache-dir jupyterlab

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

# --- SSH user and server -----------------------------------------------------
RUN useradd -m -s /bin/bash runpod \
 && mkdir -p /home/runpod/.ssh /var/run/sshd \
 && chmod 700 /home/runpod/.ssh \
 && chown -R runpod:runpod /home/runpod/.ssh \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# --- nginx: proxy HTTP :80 -> Jupyter :8888 ----------------------------------
RUN bash -lc 'cat > /etc/nginx/sites-available/jupyter.conf << "NG"\n\
server {\n\
  listen 80;\n\
  server_name _;\n\
  location / {\n\
    proxy_pass http://127.0.0.1:8888;\n\
    proxy_http_version 1.1;\n\
    proxy_set_header Upgrade $http_upgrade;\n\
    proxy_set_header Connection \"upgrade\";\n\
    proxy_set_header Host $host;\n\
  }\n\
}\n\
NG\n\
&& rm -f /etc/nginx/sites-enabled/default \
&& ln -s /etc/nginx/sites-available/jupyter.conf /etc/nginx/sites-enabled/jupyter.conf'

# --- Boot script: inject PUBLIC_KEY, set Jupyter auth, start services --------
RUN bash -lc 'cat > /usr/local/bin/runpod-start.sh << "SH"\n\
#!/usr/bin/env bash\n\
set -euo pipefail\n\
# 1) SSH key injection (optional via env PUBLIC_KEY)\n\
if [[ -n \"${PUBLIC_KEY:-}\" ]]; then\n\
  install -d -m 700 -o runpod -g runpod /home/runpod/.ssh\n\
  if ! grep -q \"$PUBLIC_KEY\" /home/runpod/.ssh/authorized_keys 2>/dev/null; then\n\
    echo \"$PUBLIC_KEY\" >> /home/runpod/.ssh/authorized_keys\n\
  fi\n\
  chown runpod:runpod /home/runpod/.ssh/authorized_keys\n\
  chmod 600 /home/runpod/.ssh/authorized_keys\n\
fi\n\
# 2) Jupyter auth config\n\
JUPYTER_ARGS=(\"--ServerApp.ip=0.0.0.0\" \"--ServerApp.port=8888\" \"--ServerApp.allow_origin=*\" \"--ServerApp.root_dir=/workspace\" \"--ServerApp.allow_remote_access=True\" \"--ServerApp.open_browser=False\")\n\
if [[ -n \"${JUPYTER_PASSWORD:-}\" ]]; then\n\
  HASH=$(python3 - <<PY\n\
from notebook.auth import passwd\n\
import os\n\
print(passwd(os.environ.get(\"JUPYTER_PASSWORD\"), algorithm=\"sha1\"))\n\
PY\n\
  )\n\
  JUPYTER_ARGS+=(\"--ServerApp.password=${HASH}\")\n\
else\n\
  # tokenless; set JUPYTER_PASSWORD in template to enforce a password\n\
  JUPYTER_ARGS+=(\"--ServerApp.token=\")\n\
fi\n\
# 3) Start services\n\
/usr/sbin/sshd\n\
# Jupyter under runpod user\n\
sudo -u runpod -E bash -lc \"mkdir -p /workspace; source /usr/local/bin/activate_pangu.sh 2>/dev/null || true; jupyter lab ${JUPYTER_ARGS[@]}\" &\n\
# nginx in foreground so container stays up\n\
exec nginx -g \"daemon off;\"\n\
SH\n\
&& chmod +x /usr/local/bin/runpod-start.sh'

# --- Defaults ---------------------------------------------------------------
WORKDIR /workspace
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

EXPOSE 22 80
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/local/bin/runpod-start.sh"]
