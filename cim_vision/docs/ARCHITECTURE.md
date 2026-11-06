# CIM-Vision — microarchitecture and numerical contract

## 1. Device-to-inference interface

The 2020 Finateu *et al.* ISSCC event-sensor design produces timestamped `(x,y,polarity)` events and uses an event-rate controller and data formatter. **This project does not implement its pixel/RO/ESP blocks.** Its RTL starts at a synchronous normalized 128×128 ROI event port and consumes one of two relative time bins. No claims are made about the paper's 1.066 GEPS readout rate being handled by this accelerator.

The source paper's closed-loop event regulation is an inspiration for future workload-adaptive buffering, NOT an implemented event-rate controller here. The prototype's `time_bin` is produced externally, and the event polarity and fine timestamp are not used.

### Coordinate mapping

`feature[6:0] = {time_bin, y[6:4], x[6:4]}`. Each 16×16 pixel tile maps to one feature in each of two sequential time bins. Multiple raw events in one tile/time bin are coalesced into a signed-positive INT8 count. If more than 127 events arrive at one feature, a partial flush splits this into several records; the sum is unchanged. A table of 32 entries is associative, output order is **not necessarily feature order**, and repeated keys are allowed across flush segments. The matrix multiply is commutative within a window up to two's-complement wrapping, so order and partial flushes do not alter final scores.

`evt_marker_only=1` is a delimiter, not a real event; use it only for empty windows with `evt_last=1`. All non-empty windows terminate with `evt_last` on their final raw event. The producer must hold raw-event fields stable until `evt_valid && evt_ready`.

## 2. Memory–compute arrangement

Each `cim_bank` owns **4 output lanes**. Each lane owns `FEATURES` signed 8-bit weights, a signed 32-bit bias and a signed 32-bit accumulator. Weight memory is sync-read and not reset; write and read ports are mutually exclusive in the normal controller. On first feature of each frame the controller initializes all accumulators from bias. For each accepted `(feature_id, value)`:

1. `COLLECT`: capture event and issue synchronous weight read in all local lanes.
2. `EXEC`: consume the now-registered weight values; update bank-local accumulators.
3. Return to `COLLECT`, or move to `EMIT` if event `last` was accepted.

The *parallel* build uses signed 8×8→16 multiplication in each lane. The *bit-serial* build uses 8 microsteps and a sign-aware shift/add based on input bit `b`. `b=7` subtracts its weight contribution; other active bits add their contribution. Both update signed 32-bit accumulators with **two's-complement wrap**, not saturation. No external weight bus crosses a macro boundary; only operand address/value and result score do.

The signed bit-serial identity is

`x = sum_{b=0}^{6}(x_b * 2^b) - x_7 * 2^7`; hence
`w*x = sum_{b=0}^{6}(x_b * (w << b)) - x_7 * (w << 7)`.

The older stand-alone `AdLIF` neuron is **not wired into this inference path**; a network of quantized ReLUs processing event-derived features is **not a spiking neural network**.

**Interpretation:** this is a meaningful bank-local digital near-memory computation organization and a portable functional model of CIM-style arithmetic. Standard FPGA synthesis does not produce SRAM bitcell arithmetic; the weight word emerges from a RAM to surrounding logic. Real SRAM-CIM must physically combine sensing/readout and Boolean/arithmetic processing in the memory macro itself.

## 3. Layer-1 / layer-2 link

Full hardware-only forward pass:

```
Raw event (x,y,t,frame_last)
       |
       v
8x8 tile mapping + associative count coalescer (32 entries)
       |
       v
(index[6:0], signed_count[7:0], last)   [indexed stream]
       |
       v
CIM-Layer1: FEATURES=128, OUTPUTS=32, 8 banks x 4 lanes
       |
       | 32 signed INT32 accumulated hidden values, serialized
       v
relu_q3: int8 = clip((max(acc,0)+2)//4, 0,127)
       |
       v
CIM-Layer2: FEATURES=32, OUTPUTS=4, 1 bank x 4 lanes
       |
       v
4 signed INT32 scores, host takes argmax
```

The training model uses **input counts** as unscaled integer values. For layer 1, INT8 weights and INT32 biases are scaled by 32; hidden output is ReLU, quantized to Q3 (scale 8), with positive half-up rounding; layer-2 weights are INT8 scale 32; layer-2 biases are INT32 scale 256. Its final scores are Q8 (scale 256) signed values. Neither hardware layer uses a softmax. Biases are reloaded into each lane's accumulator at frame start.

For the given model, `W1` is `(128,32)`, `W2` is `(32,4)`. On-chip weight storage is 4096+128=4224 bytes; biases 36×4=144 bytes. Accumulator storage is another 144 bytes, not counted in persistent weights/biases. Model memories may map to flip-flops, LUTRAM or block RAM depending on vendor and hierarchy; mapping is NOT yet measured.

## 4. Cycle contracts: *design specification, not proven by waveform*

`cim_layer` states IDLE→COLLECT→EXEC→EMIT→IDLE. IDLE takes one clock to initialize bias and transition to collect, and does not accept the first event until COLLECT. One record takes one accepted input/read cycle + one EXEC cycle in parallel mode, or one accepted input/read + 8 EXEC cycles in bit-serial mode. `out_valid` is asserted for each of the OUTPUTS serialized scores while in EMIT; if `out_ready=0`, `out_data`, `out_col`, and `out_last` remain stable. The second layer can backpressure the first during hidden-score transfer.

A mode-independent performance comparison must use both the same weight memory technology, same input vectors, same output values, same memory clock/timing, and identical host/encoder constraints. **Counting only MAC active cycles is insufficient to prove end-to-end speedup**. Particularly, raw event acquisition+32-entry association, 32 hidden-result serialization and 4 class outputs can dominate short windows.

## 5. Invariants and failure modes

- Outputs must be bit-for-bit identical for dense and sparse enumerations, and for parallel and signed-bit-serial modes.
- `cfg_ready` is low while inference is active; only layer-specific valid configuration writes update local memories. Invalid layer-2 index/output sets sticky protocol error. Clear errors with reset.
- After reset, **all weight cells are undefined** until full programming; biases and accumulators are zero. This prevents resetting large memory arrays but demands a strict host programming phase.
- `evt_valid` may stall during partial flushes. A producer may NOT interpret `evt_ready=0` as a dropped event.
- Associative table spills are partial, *without* frame-final flag; retries preserve event count even when one tile receives more than 127 events.
- The full system requires a single clock; asynchronous camera readout/MIPI/USB clock domain crossing is intentionally outside scope.
- A full-rate real sensor cannot be attached without rate conversion, CDC, buffers, overload policy and throughput verification.
- A reissued frame must be delimited; no inter-frame overlapping inference buffers exist.

## 6. Independent reference checks

`tools/model.py` implements (1) dense integer array multiplication and (2) a sequential event-by-event update loop, completely apart from the RTL. The pytest gate checks exact logits, repeated feature keys, fully empty vectors, negative multiplication, signed bit-serial identity, wraparound and frozen fixtures. HDL benches independently exercise configured weights, sparse/dense streams, bit-serial modes, output stalls, 32-entry overflow via reduced 8-entry capacity, count overflow via repeated events, and integrated event-to-logit parity.

The tests are **written**, but the HDL gates are not marked PASS until Icarus and Verilator have been run on a machine containing those tools.
