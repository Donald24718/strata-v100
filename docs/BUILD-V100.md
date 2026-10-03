# Building Strata for Volta

## Environment that is known to work

| Item | Value |
|---|---|
| OS | Ubuntu 24.04 (glibc 2.39) |
| Driver | 580.178.04 |
| CUDA toolkit | 12.8 (`/usr/local/cuda-12.8/bin/nvcc`) |
| gcc | 13.3.0 |
| cmake | 3.28.3 |
| Python | 3.12 |
| `CMAKE_CUDA_ARCHITECTURES` | `70` |

## Engine

```bash
cmake -S . -B build -G Ninja -DSTRATA_ENABLE_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=70 \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.8/bin/nvcc \
  -DSTRATA_BUILD_TESTS=OFF
ninja -C build -k 0 -j "$(nproc)"
```

On 0.1.31 or newer add `-DSTRATA_EXPERIMENTAL_SM60=ON` and skip
`patches/volta-sm70.patch`.

If the build wants to fetch llama.cpp over HTTPS and your network blocks
`github.com`, pin a local copy with
`-DFETCHCONTENT_SOURCE_DIR_STRATA_LLAMACPP=/path/to/llama.cpp`.

## Vision encoder (optional)

```bash
cmake -S tools/vision -B build-vision-cuda -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_DIR=/path/to/llama.cpp -DSTRATA_VISION_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=70 -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.8/bin/nvcc
cmake --build build-vision-cuda --target strata-vision
```

CPU build (`-DSTRATA_VISION_CUDA=OFF`) is much slower per image but gives the
VRAM back to the expert cache.

## Pack and MTP

- Pack: `tools/iq_pack.py --gguf <first shard> --out packs/<name>`. A native pack
  written this way stores 16-bit floats verbatim (index kinds 4 = BF16, 5 = F16).
  This matters: a pack that stores `blk.1.ple_conv1d.weight` as F32 is read as
  fp16 bits by the pinned PLE kernels and the output becomes garbage that looks
  fine. Check `packs/<name>/index.txt` — the conv1d row must be 2 bytes per
  element.
- MTP: `tools/mtp_fetch.py` pulls the `mtp.*` tensors by HTTP range from the
  BF16 checkpoint. Use the full head, not a trimmed draft vocabulary.
