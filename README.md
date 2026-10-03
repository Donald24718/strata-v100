# strata-v100 — Strata on Tesla V100 (Volta, sm_70)

Third-party patches, build script and real measurements that make
[Strata](https://github.com/Niko1221/Strata) run on NVIDIA **Volta** cards
(compute capability 7.0 — Tesla V100 PCIe and SXM2).

**Not official, not endorsed.** See [NOTICE](NOTICE). Upstream is MIT; the
upstream LICENSE is reproduced in [LICENSE](LICENSE).

## Why this exists

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

- Volta has no bfloat16. Upstream's sm_70 prefill path is not the fast one; an
  open upstream PR (#540) claims +22-23% by moving prefill to FP16 tensor cores.
  Not merged as of 0.1.38.
- 262K context on a 16 GB card only works because experts stay in system RAM and
  the resident KV window is capped. RAM matters more than VRAM here.
- 8 GB cards are listed as unsupported by upstream docs; we have not measured one.
