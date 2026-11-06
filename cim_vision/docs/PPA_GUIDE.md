# Physical implementation and evaluation: what still needs to be proven

## FPGA target and physical integration boundary

Proposed concrete board: **Digilent Arty A7-100T** (Xilinx Artix-7 `xc7a100tcsg324-1`), 100 MHz fabric clock target as a **goal** only. `tools/vivado_synth.tcl` is synthesis-only and creates an illustrative 10 ns timing constraint. It does not implement/place/route, assign correct board pinout, attach UART, flash configuration or produce a tested bitstream. Do not report fmax, LUT, BRAM, DSP, timing or power as measured until reports are generated.

Required RTL-to-FPGA work: (1) choose official board-master XDC; (2) wrap `cfg`/`event` signals in an actual UART or AXI-Lite/AXI-Stream slave with framing and checksum, (3) add input CDC/FIFO if external clock; (4) constrain all clocks and I/O; (5) run `synth_design`, `opt_design`, `place_design`, `route_design`, STA; (6) construct Python host that sends weights/events and reads scores with CRC and repeatability; (7) repeat golden-vector tests on board, capture SPI/UART traces and logic-analyzer screenshots.

### Measurements to preserve

| Metric | Method | Status |
|---|---|---|
| Logic LUT / FF / DSP / RAMB | Vivado `report_utilization` by module | Not measured |
| Fmax / WNS / critical path | post-route STA, correct clocks and I/O | Not measured |
| Cycles/frame | RTL testbench from first accepted input through last output handshake, exclude loading | Not measured |
| Sustained windows/s | contiguous frames, realistic source/sink stalls | Not measured |
| Internal memory activity | per-bank read/write and arithmetic enable counters | Software proxy only |
| Power and energy/frame | post-route SAIF/VCD + Xilinx Power Estimator and ideally board current/power sensors | Not measured |
| True SRAM-CIM energy | SPICE/PDK and measured macro or independently characterized foundry macro | Not measured |
| Classification accuracy | subject-disjoint real DVS recordings, identical model | Synthetic only |

### Fair architecture-controlled ablation

A. Dense: all 128 indexed inputs, including zeros, through the **same exact hardware**; B. Sparse: nonzero indexed input stream; C. Dense zero-gated: architecturally suppress weight read/multiplier on zeros without compressing the stream; D. Bit-serial sparse: actual shift/add implementation rather than clock-domain reinterpretation; E. Event coalescer with and without associative aggregation and spill. For each version, track active arithmetic, memory reads, source bytes, full-window cycles including encoder, stalls, logic area, RAM mapping, clock frequency and activity-based energy **separately**.

This specification intentionally avoids claiming a speedup from an 86.26% count reduction. There are nontrivial end-to-end overheads. A 32-entry CAM may itself dissipate energy in many parallel comparisons; it must be measured rather than described as inherently low-power.

### Physical digital SRAM-CIM research extension

A digital SRAM-CIM silicon claim needs either a foundry-provided compute-capable SRAM macro or a custom bitcell/periphery, an explicit bitline/wordline transaction, a defined sense-amplifier or digital popcount/adder implementation and a proper test flow. OpenRAM **ordinary** SRAM alone is not a CIM proof. Place/route a memory macro with actual `.lib`, `.lef`, GDS, behavioral and gate-level views and check DRC/LVS/STA. Characterize per-operation energy and collision/retention/read disturb constraints. Report the separate FPGA emulation and physical macro experiments; never conflate their results.
