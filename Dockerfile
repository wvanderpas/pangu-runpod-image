FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# (Optional) small utilities your installer might expect
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget vim git tzdata bash \
 && rm -rf /var/lib/apt/lists/*

# Copy your installer and run it during build
COPY install-pangu-runpod.sh /tmp/install.sh
RUN chmod +x /tmp/install.sh && /tmp/install.sh && rm -f /tmp/install.sh

WORKDIR /workspace
ENV PATH="/workspace/bin:${PATH}"
