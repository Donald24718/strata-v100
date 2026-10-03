# What actually bites on Volta

Measured on Ubuntu 24.04, driver 580.178.04, CUDA 12.8, gcc 13.3.0, cmake 3.28.3,
glibc 2.39.

1. **`nvcc` is usually not on PATH.** On this machine it lives at
   `/usr/local/cuda-12.8/bin/nvcc`. Pass it explicitly
   (`-DCMAKE_CUDA_COMPILER=`), otherwise cmake picks the wrong compiler.
2. **The release engine refuses to start.** `device.cu` throws
   "Strata needs compute capability 7.5 or newer". That is the runtime guard,
   not a driver problem. Patch it (0.1.30) or build with
   `-DSTRATA_EXPERIMENTAL_SM60=ON` (0.1.31+).
3. **Docs and code disagree.** `docs/MULTI_GPU.md` still says anything below 7.5
   is unsupported and that setup will refuse it, while the code has admitted
   Volta behind a flag since 0.1.31. Trust the code, expect the docs to say no.
4. **No bfloat16 on Volta.** Expect prefill to be slower than the README numbers
   for RTX cards; those are measured on RTX 5070 / RX 9070 XT.
5. **VRAM decides the expert cache, not the quantisation.** Enabling the GPU
   vision encoder costs about 1.3 GiB and the engine adapts its expert cache down
   (observed 5392 -> 4573 experts). If you need the extra experts, run the vision
   encoder on CPU instead — roughly 7.3 s/image versus 0.17 s/image.
6. **RAM matters more than VRAM.** Experts are memory-mapped from disk/RAM. A
   16 GB card with plenty of system RAM beats a bigger card with little RAM.
7. **Do not compute decode speed as generated-tokens / total-request-time.**
   That includes prompt processing. Read the engine's own timing lines.
8. **A 65-image request used to die with an EOF.** That is the vision LRU bug in
   `serve/server.py`; `patches/vision-eof-fix.patch` fixes it. It is not Volta
   specific and upstream has not fixed it.

9. **nvcc warns about your architecture.** Building for sm_70 prints:
   `Support for offline compilation for architectures prior to '<compute/sm/lto>_75'
   will be removed in a future release`. That is NVIDIA deprecating pre-Turing
   code generation, not a Strata problem. It is a warning today, and it is the
   reason to pin a CUDA version (12.8 here) instead of tracking the latest.
