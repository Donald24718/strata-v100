# strata-v100 — Strata on Tesla V100 (Volta, sm_70)

Third-party patches, build script and real measurements that make
[Strata](https://github.com/Niko1221/Strata) run on NVIDIA **Volta** cards
(compute capability 7.0 — Tesla V100 PCIe and SXM2).

**Not official, not endorsed.** See [NOTICE](NOTICE). Upstream is MIT; the
upstream LICENSE is reproduced in [LICENSE](LICENSE).

## Status (2026-10-06): upstream carries Volta now — this repo is the fallback

Upstream **v0.1.39 (2026-10-04)** ships an older-hardware path that covers
Volta. Pascal and Volta cards (P40, P100, GTX 10, **V100**, Titan V) get a
second engine built with **CUDA 12.9** — CUDA 13 cannot compile `sm_70` at all.
It is picked when such a card is named (`--gpu N` / `--gpus`, or `--cuda 12`),
and upstream says **"the Volta prompt attention and the BF16 path through FP16
/ fp32 are compiled into this engine only"**. The PRs behind it are #395 #600
**#540** #655 #627 — #540 is the FP16 tensor-core prefill this README used to
list as an open upstream PR; it has landed. Upstream now also carries reporter
numbers for V100 (`docs/OLDER_GPUS.md`: prompts 1,123-1,251 tok/s on
UD-IQ4_XS), and 0.1.33 (#371) fixed the prompt-attention kernel used when a
V100 sits in a layer split.

**So: start from upstream for anything new.** This repo stays as the
**fallback**, and the reason is upstream's own wording — the whole
older-hardware section is labelled *experimental*: "three opt-in paths that
community members wrote and measured on their own machines. We have none of
this hardware." The Volta engine is compile-checked and unit-tested upstream,
but the author has never run it on a Pascal or Volta card. Two concrete
failure modes this repo still covers:

- a regression in that experimental Volta path leaves a Volta box with no
  working engine, and this tree is a measured-good one to drop back to;
- CUDA 13 is upstream's default and cannot target `sm_70`; if the CUDA 12.9
  build path is dropped or breaks, the recipe here still works.

The fallback target is the combination running in production here: upstream
`v0.1.30` + the two arch guards in `patches/volta-sm70.patch`, verified
byte-identical. Measured on a 16 GB V100: 122B IQ3_S at 262K context,
**40-46 tok/s decode**, expert cache 3,448 slots / 6.75 GiB, ~62% hit,
15.4 of 16 GiB used, 2+ days without a restart.

```bash
./scripts/build-v100.sh v0.1.30     # the pinned, measured-good combination
./scripts/verify-v100.sh
```

What upstream has that this pinned tree does **not**: the Volta FP16
tensor-core prefill (#540), prompt-path gains (0.1.38 #372/#374/#413), the
262K-524K attention top-k histogram (0.1.39 #603), `expert_profile_save`
(0.1.36 #477), an engine-silence watchdog (0.1.37 #481), and the no-API-key
host/Origin hardening (0.1.38). None of these justify replacing a working
engine on a box that is already serving; all of them are reasons to prefer
upstream when starting fresh.


## Why this exists (historical — see Status above)

Strata's release engine does not contain Volta support, and its docs list
anything below compute capability 7.5 as unsupported. Upstream added a build
flag for it in 0.1.31, but the author states sm_70 stays *community-tested* and
"won't be in the ready-made engine". So on Volta you must build from source —
and the documentation for doing that does not exist anywhere. This repo is that
documentation, plus the patches.

## What is here

| Path | What it is |
|---|---|
| `patches/volta-sm70.patch` | Two guards that refuse cc < 7.5 (build-time arch check, runtime device check) lowered to 70. **Obsolete on 0.1.31+** — use `-DSTRATA_EXPERIMENTAL_SM60=ON` instead. |
| `patches/vision-eof-fix.patch` | Vision requests with more images than the 64-entry LRU cache held died with an EOF mid-request, because embeddings were read after the whole encode loop. Any hardware. |
| `patches/mtp-hf-mirror.patch` | Point the MTP fetcher at `hf-mirror.com`. Optional; only useful where huggingface.co is unreachable. |
| `scripts/build-v100.sh` | Fetch an upstream tag, apply the patches, configure and build for sm_70. |
| `scripts/verify-v100.sh` | Smoke test that reads the engine's own timing lines. |
| `docs/BUILD-V100.md` | Full build: environment, engine, vision, pack, MTP. |
| `docs/BENCHMARKS.md` | Measured numbers on V100, ours and community, each labelled with its conditions. |
| `docs/TROUBLESHOOTING.md` | The things that actually bite on Volta. |
| `config.example.json` | A working 262K configuration on one 16 GB card. |

## Fastest path

```bash
./scripts/build-v100.sh v0.1.30      # or a newer tag; the Volta patch is skipped automatically
./scripts/verify-v100.sh
```

## Verified, not guessed

The three patches apply cleanly to a pristine upstream `v0.1.30` tree, and after
applying them the four touched files are **byte-identical** to the tree running
in production here. That check was run on 2026-10-03; see
[docs/BENCHMARKS.md](docs/BENCHMARKS.md) for what the resulting engine measures.

## Known limits, stated plainly

- Volta has no bfloat16. The sm_70 prefill path used to be the slow one; the
  FP16 tensor-core prefill (PR #540, +22-23%) landed in **0.1.39**, but only
  inside the CUDA 12.9 older-GPU engine. This repo's pinned 0.1.30 tree does
  not have it.
- 262K context on a 16 GB card only works because experts stay in system RAM and
  the resident KV window is capped. RAM matters more than VRAM here.
- 8 GB cards are listed as unsupported by upstream docs; we have not measured one.
