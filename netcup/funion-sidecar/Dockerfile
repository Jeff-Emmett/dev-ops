FROM python:3.11

# Build deps for llama-cpp-python (cmake, gcc are needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake build-essential ninja-build \
    && rm -rf /var/lib/apt/lists/*

# CPU-only llama-cpp-python; ~2 min compile
RUN pip install --no-cache-dir llama-cpp-python==0.3.2

WORKDIR /sidecar
