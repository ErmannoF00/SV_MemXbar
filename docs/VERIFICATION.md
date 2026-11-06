# Verification record

This report distinguishes source code, observed simulation results, and tests without current evidence. Historical memristor code is not compiled into the digital inference datapath.

## User-reported successful WSL tests — 2026-11-06

- `make -C cim_vision reference`: 11 Python tests passed.
- `make -C cim_vision sim-all`: all HDL testbenches completed under Icarus Verilog after the reserved `expect` identifier was changed to `expected_scores`.
- Parallel MLP: indexed-sparse 2,548 cycles, dense 7,865 cycles for 24 synthetic windows.
- Bit-serial MLP: indexed-sparse 10,864 cycles, dense 34,745 cycles for 24 synthetic windows.
- Signed-extrema tests passed for both arithmetic modes.
- Event-to-inference top tests passed with 10 frames in both arithmetic modes, including coalescer spills.
- `python3 tools/check_legacy_sources.py`: six historical RTL and testbench files matched their baseline hashes.

The measured cycle ratios on those 24 windows are 7865/2548 = 3.0867× (parallel) and 34745/10864 = 3.1981× (bit-serial) for dense relative to indexed sparse. This is not a routed FPGA speedup. The testbench includes test-vector timing; memory programming is excluded from the reported `inference_cycles`.

## Gates still requiring independent confirmation

1. `make -C cim_vision lint` after the latest signed-width and subpixel warning fixes.
2. `make -C cim_vision synth`, Yosys structural check and resource report.
3. `make -C cim_vision bench-rtl`, persisted `cim_vision/build/rtl_benchmark/performance.json`.
4. GitHub Actions on the committed revision and clean runner.
5. Vendor FPGA synthesis/place-and-route, board execution and real event-data evaluation. These are not yet shown.

The original memristor model is behavioral. Neither this project nor the figures demonstrate an analog 1T1R macro performing the quantized classifier; the synthesizable accelerator uses digital memories and arithmetic.

## Exact release-gate commands

```bash
cd ~/projects/SV_MemXbar
python3 tools/check_legacy_sources.py
make -C cim_vision reference && \
make -C cim_vision sim-all && \
make -C cim_vision lint && \
make -C cim_vision synth && \
make -C cim_vision bench-rtl
```

The checksum file's paths are relative to `cim_vision/`; run its verification from that directory instead:

```bash
(cd cim_vision && sha256sum -c SHA256SUMS)
```

`sha256sum -c cim_vision/SHA256SUMS` from the repository root is **not** an equivalent command. Do not use it as a release criterion. Review `git diff --check` and `git status --short` before committing; the testbench backup `cim_vision/tests/tb_signed_core.sv.pre_identifier_fix` must not be staged.
