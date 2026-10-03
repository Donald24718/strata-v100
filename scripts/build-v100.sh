#!/usr/bin/env bash
# One-shot build of Strata for Volta (sm_70). Tested on Ubuntu 24.04, CUDA 12.8.
# Usage:  ./build-v100.sh [engine-tag]        default v0.1.30
# Env:    NVCC=/path/to/nvcc   ARCH=70   LLAMACPP=/path/to/llama.cpp
set -euo pipefail
TAG="${1:-v0.1.30}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/src-tree"
NVCC="${NVCC:-/usr/local/cuda-12.8/bin/nvcc}"
ARCH="${ARCH:-70}"

[ -x "$NVCC" ] || { echo "nvcc not found at $NVCC — set NVCC=/path/to/nvcc"; exit 1; }

if [ ! -d "$SRC" ]; then
  echo "downloading upstream $TAG"
  mkdir -p "$SRC"
  curl -sL "https://codeload.github.com/Niko1221/Strata/tar.gz/refs/tags/$TAG" \
    | tar xz --strip-components=1 -C "$SRC"
fi

cd "$SRC"
for p in "$HERE"/patches/*.patch; do
  patch -p1 --dry-run --silent < "$p" >/dev/null 2>&1 || { echo "already applied or does not fit: $(basename "$p")"; continue; }
  patch -p1 --silent < "$p" && echo "applied $(basename "$p")"
done

# On 0.1.31+ the Volta patch is obsolete: the official flag admits sm_70 instead.
FLAG=""
case "$TAG" in
  v0.1.3[1-9]*|v0.1.[4-9][0-9]*) FLAG="-DSTRATA_EXPERIMENTAL_SM60=ON"; echo "using upstream flag $FLAG (Volta patch not needed)";;
esac

# llama.cpp: upstream FetchContent runs `git clone https://github.com/ggml-org/llama.cpp`,
# which hangs on networks where github.com is unreachable at the IP layer. Pin a local
# copy of the exact commit upstream asks for; the tag is read out of CMakeLists so this
# keeps working when the pin moves.
LLAMACPP="${LLAMACPP:-$HERE/llama-pin}"
LLAMA_TAG=$(sed -n '/FetchContent_Declare(strata_llamacpp/,/GIT_SHALLOW/p' CMakeLists.txt \
            | sed -n 's/.*GIT_TAG \([0-9a-f]\{7,40\}\).*/\1/p' | head -1)
EXTRA=""
if [ -n "$LLAMA_TAG" ]; then
  if [ ! -d "$LLAMACPP" ]; then
    echo "fetching pinned llama.cpp $LLAMA_TAG via codeload"
    mkdir -p "$LLAMACPP"
    curl -sL "https://codeload.github.com/ggml-org/llama.cpp/tar.gz/$LLAMA_TAG" \
      | tar xz --strip-components=1 -C "$LLAMACPP"
  fi
  EXTRA="-DFETCHCONTENT_SOURCE_DIR_STRATA_LLAMACPP=$LLAMACPP"
  echo "llama.cpp pinned at $LLAMACPP ($LLAMA_TAG)"
fi

cmake -S . -B build -G Ninja -DSTRATA_ENABLE_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES="$ARCH" -DCMAKE_CUDA_COMPILER="$NVCC" \
  -DSTRATA_BUILD_TESTS=OFF $FLAG $EXTRA
ninja -C build -k 0 -j "$(nproc)"
echo "done: $SRC/build/strata"
