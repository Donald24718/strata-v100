# Measured on Volta

Every number below states what produced it. Estimates are labelled. Upstream's
own headline numbers (IQ3_S 53 tok/s) are measured on an RTX 5070 12 GB and an
RX 9070 XT 16 GB — do not expect them on Volta.

## Ours — one Tesla V100-SXM2-16GB

Conditions: Ubuntu 24.04, driver 580.178.04, CUDA 12.8, engine **0.1.30** with
the three patches in this repo, model Qwen3.8-Flash-Next GSQ-RCO **IQ3_S**
(two shards), `--max-context 262144 --kv fp16 --kv-resident 32768 --ple-io ram
--spec 4 --spec-min-p 0.5 --vision --vram-reserve-mib 700 --pool-workers 22`.
Numbers are the engine's own timing lines, 2026-10-03.

| Metric | Measured |
|---|---|
| Decode | **40.3 – 46.5 tok/s** |
| Prefill, long context | **764 – 804 tok/s** (batches of 81K–98K freshly read tokens; engine lines such as `+ 98111 read in 123336 ms (795.5 tok/s)`) |
| Prefill, small fresh batch | 429 – 499 tok/s (8K-scale fresh reads) |
| Prefill, tiny fresh read | not a throughput figure — a few hundred fresh tokens inside a reused prefix reports 141–303 tok/s because the elapsed time also covers reuse and scheduling. Do not quote it as prefill speed. |
| Prefix reuse | e.g. `prompt 89147 tokens = 88543 reused + 604 read` |
| Draft acceptance | **73.4 – 92.6 %** (e.g. 1373/1748, 831/1130, 1081/1472, 87/94) |
| VRAM in use | ~15.8 GiB of 16 GB |
| Vision encoder on GPU | ~1.3 GiB VRAM, ~0.17 s/image |
| Vision encoder on CPU | ~7.3 s/image, frees that 1.3 GiB |
| Expert cache | adapts **5392 -> 4573** experts when GPU vision is enabled |

Prefill throughput depends strongly on how many tokens are actually fresh. The
764–804 tok/s figures come from requests that had to read 80K–98K new tokens;
most everyday requests reuse the conversation prefix and read only a few hundred,
and the engine's per-line rate for those is meaningless as a throughput number.
Quote the large-batch figures for prefill.

## Community reports (same card family, different setups)

- **`zipenghao/strata-v100-sm70`** — two V100 **PCIe**, no NVLink, Xeon without
  AVX-512, engine 0.1.24 plus their own patches: **decode 43.4 tok/s, prefill
  865 tok/s at 117K**. Their report also documents a correctness bug where
  `ple_conv1d.weight` stored as F32 is read as fp16 bits: output is garbage that
  looks normal, and the shipped parity tests stay green.
- **`loopwhile/v100-x2-strata-qwen3.8-flash-next`** — two V100 SXM2, engine
  **0.1.31** pinned, CUDA 12.9.1 inside Docker (no host CUDA toolkit),
  `CMAKE_CUDA_ARCHITECTURES=70`, AVX2 fallback for IQ expert CPU work, topology
  of **two independent 128K mmap agents**, one per card.
- **Upstream issue #236** — 32 GB V100, `swift-1.5-iq3_xxs`: full 256K context
  works but with **220 fewer experts** in VRAM, around **45 tok/s at 50K context**.

## Not measured

- 8 GB cards. Upstream docs list under-8 GB and sub-7.5 cards as unsupported for
  multi-GPU; nobody here has measured a Volta under 16 GB.
- Engine 0.1.38. Our production engine is 0.1.30; the newer chain is untested on
  this machine, and one upstream change (#463) made a Q2_0 128K case slower
  (75.1 -> 70.9) on newer hardware.
