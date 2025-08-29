#!/usr/bin/env bash
set -euo pipefail

# --- Keep installs/caches on the big persistent volume -----------------------
mkdir -p /workspace/{tmp,pip-cache}
export TMPDIR=/workspace/tmp
export PIP_CACHE_DIR=/workspace/pip-cache

# --- Minimal system deps ------------------------------------------------------
apt-get update -y
apt-get install -y --no-install-recommends git git-lfs curl build-essential ca-certificates vim
apt-get clean
rm -rf /var/lib/apt/lists/*

# --- Create venv in /workspace (persists across resets) -----------------------
python3 -m venv /workspace/pangu-venv
source /workspace/pangu-venv/bin/activate
python -m pip install --upgrade pip setuptools wheel

# --- Install ONNX Runtime GPU + ai-models + Pangu plugin ----------------------
# Use the CUDA+cuDNN extras so required NVIDIA libs are installed via pip.
unset LD_LIBRARY_PATH || true
python -m pip install --no-cache-dir -U "onnxruntime-gpu[cuda,cudnn]" ai-models ai-models-panguweather

python -m pip install --no-cache-dir -U "onnxruntime-gpu[cuda,cudnn]" matplotlib basemap


# --- Make the CUDA EP find the bundled NVIDIA libs (cuDNN, cuBLAS, etc.) -----
# (Fix for: "libcudnn.so.9: cannot open shared object file")
NVIDIA_LIBS_DIRS="$(
python - <<'PY'
import site,glob,os
sp = site.getsitepackages()[0]
dirs = [d for d in glob.glob(os.path.join(sp,'nvidia','*','lib')) if os.path.isdir(d)]
print(':'.join(dirs))
PY
)"
export LD_LIBRARY_PATH="${NVIDIA_LIBS_DIRS}:${LD_LIBRARY_PATH:-}"

# --- Quick verification: CUDAExecutionProvider should be present --------------
python - <<'PY'
import onnxruntime as ort
prov = ort.get_available_providers()
print("ONNX Runtime providers:", prov)
assert "CUDAExecutionProvider" in prov, "CUDA EP missing (check LD_LIBRARY_PATH fix above)"
print("✅ CUDAExecutionProvider ready")
PY

# --- Optional: tiny activation helper for future shells -----------------------
cat >/workspace/activate_pangu.sh <<'SH'
#!/usr/bin/env bash
set -e
source /workspace/pangu-venv/bin/activate
# Recompute bundled NVIDIA lib paths and export
NVIDIA_LIBS_DIRS="$(python - <<'PY'
import site,glob,os
sp=site.getsitepackages()[0]
dirs=[d for d in glob.glob(os.path.join(sp,'nvidia','*','lib')) if os.path.isdir(d)]
print(':'.join(dirs))
PY
)"
export LD_LIBRARY_PATH="${NVIDIA_LIBS_DIRS}:${LD_LIBRARY_PATH:-}"
python - <<'PY'
import onnxruntime as ort
print("Providers:", ort.get_available_providers())
PY
echo "Pangu-Weather ready."
SH
chmod +x /workspace/activate_pangu.sh

echo "-----------------------------------------------------------------"
echo "✅ Install done. To use in a new shell:"
echo "   source /workspace/activate_pangu.sh"
echo
echo "Try:"
echo "   ai-models list"
echo "   ai-models panguweather --help"
echo "-----------------------------------------------------------------"
#!/usr/bin/env bash
set -euo pipefail

# --- Keep installs/caches on the big persistent volume -----------------------
mkdir -p /workspace/{tmp,pip-cache}
export TMPDIR=/workspace/tmp
export PIP_CACHE_DIR=/workspace/pip-cache

# --- Minimal system deps ------------------------------------------------------
apt-get update -y
apt-get install -y --no-install-recommends git git-lfs curl build-essential ca-certificates vim
apt-get clean
rm -rf /var/lib/apt/lists/*

# --- Make sure GPU is visible -------------------------------------------------
nvidia-smi || { echo "❌ NVIDIA driver/GPU not visible"; exit 1; }

# --- Create venv in /workspace (persists across resets) -----------------------
python3 -m venv /workspace/pangu-venv
source /workspace/pangu-venv/bin/activate
python -m pip install --upgrade pip setuptools wheel

# --- Install ONNX Runtime GPU + ai-models + Pangu plugin ----------------------
# Use the CUDA+cuDNN extras so required NVIDIA libs are installed via pip.
unset LD_LIBRARY_PATH || true
python -m pip install --no-cache-dir -U "onnxruntime-gpu[cuda,cudnn]" ai-models ai-models-panguweather ai-models-panguweather-gfs

# --- Make the CUDA EP find the bundled NVIDIA libs (cuDNN, cuBLAS, etc.) -----
# (Fix for: "libcudnn.so.9: cannot open shared object file")
NVIDIA_LIBS_DIRS="$(
python - <<'PY'
import site,glob,os
sp = site.getsitepackages()[0]
dirs = [d for d in glob.glob(os.path.join(sp,'nvidia','*','lib')) if os.path.isdir(d)]
print(':'.join(dirs))
PY
)"
export LD_LIBRARY_PATH="${NVIDIA_LIBS_DIRS}:${LD_LIBRARY_PATH:-}"

# --- Quick verification: CUDAExecutionProvider should be present --------------
python - <<'PY'
import onnxruntime as ort
prov = ort.get_available_providers()
print("ONNX Runtime providers:", prov)
assert "CUDAExecutionProvider" in prov, "CUDA EP missing (check LD_LIBRARY_PATH fix above)"
print("✅ CUDAExecutionProvider ready")
PY

# --- Optional: tiny activation helper for future shells -----------------------
cat >/workspace/activate_pangu.sh <<'SH'
#!/usr/bin/env bash
set -e
source /workspace/pangu-venv/bin/activate
# Recompute bundled NVIDIA lib paths and export
NVIDIA_LIBS_DIRS="$(python - <<'PY'
import site,glob,os
sp=site.getsitepackages()[0]
dirs=[d for d in glob.glob(os.path.join(sp,'nvidia','*','lib')) if os.path.isdir(d)]
print(':'.join(dirs))
PY
)"
export LD_LIBRARY_PATH="${NVIDIA_LIBS_DIRS}:${LD_LIBRARY_PATH:-}"
python - <<'PY'
import onnxruntime as ort
print("Providers:", ort.get_available_providers())
PY
echo "Pangu-Weather ready."
SH
chmod +x /workspace/activate_pangu.sh

echo "-----------------------------------------------------------------"
echo "✅ Install done. To use in a new shell:"
echo "   source /workspace/activate_pangu.sh"
echo
echo "Try:"
echo "   ai-models list"
echo "   ai-models panguweather --help"
echo "-----------------------------------------------------------------"



# Preparing the system
apt-get update
apt-get install libnetcdff-dev libopenjp2-7-dev gfortran make unzip git cmake wget -y

echo 'finished installing 1'

# Downloading the source code
cd && mkdir source_builds
cd source_builds && mkdir eccodes && cd eccodes && wget https://confluence.ecmwf.int/download/attachments/45757960/eccodes-2.42.0-Source.tar.gz
tar -xzf eccodes-2.42.0-Source.tar.gz

echo 'finished installing 2'

# Building
mkdir build && cd build
mkdir /workspace/src/eccodes
cmake -DCMAKE_INSTALL_PREFIX=/usr/src/eccodes -DENABLE_JPG=ON eccodes-2.42.0-Source
make
ctest
make install
cp -r /usr/src/eccodes/bin/* /usr/bin

# Setting environment variables
echo 'export ECCODES_DIR=/usr/src/eccodes' >> ~/.bashrc
echo 'export ECCODES_DEFINITION_PATH=/usr/src/eccodes/share/eccodes/definitions' >> ~/.bashrc
source ~/.bashrc

# Copying shared libraries and header files to their standard locations
cp $ECCODES_DIR/lib/libeccodes.so /usr/lib
cp /usr/src/eccodes/include/* /usr/include/
cd /

mkdir /workspace/grib/
mkdir /workspace/Maps/
