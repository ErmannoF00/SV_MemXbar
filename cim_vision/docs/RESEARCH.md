# Research positioning, falsifiable hypotheses, and study plan

## What is not novel

The concept of processing event-camera activity sparsely and using a digital compute-in-memory fabric is established. Chauvaux *et al.*, “An Event-Based Digital Compute-In-Memory Accelerator with Flexible Operand Resolution and Layer-Wise Weight/Output Stationarity,” arXiv:2410.23082 (2024) describes **FlexSpIM**, a fabricated 40 nm digital CIM macro with weight/membrane co-storage, configurable precision and a large-scale DVS gesture evaluation. He *et al.*, “S3Net: Spatiotemporally Separated Sparse Network for Neuromorphic Vision Processing” (AAAI 2026) explores more sophisticated asynchronous sparse event processing. The source ISSCC 2020 event sensor (Finateu *et al.*) already uses event-rate regulation and compressed vectorized readout. Do NOT present this work as the first event-based CIM, first event accelerator, first sparse vision system or first digital SNN.

References (public):
- Finateu *et al.*, ISSCC 2020, “A 1280×720 Back-Illuminated Stacked Temporal Contrast Event-Based Vision Sensor ... 1.066GEPS ...” (uploaded source).
- Chauvaux *et al.*, arXiv:2410.23082 — https://arxiv.org/abs/2410.23082
- He *et al.*, AAAI 2026 S3Net — https://doi.org/10.1609/aaai.v40i6.42467
- Amir *et al.*, CVPR 2017, DVS Gesture and TrueNorth — https://research.ibm.com/publications/a-low-power-fully-event-based-gesture-recognition-system
- He *et al.*, IEEE Solid-State Circuits Magazine (2025), SRAM/eDRAM CIM design and evaluation — DOI: 10.1109/MSSC.2025.3549358.

The provided `Superpixel.pdf` is a 47-page **scanned** US patent (`US 11,979,673 B2`), with no reliable searchable text in the provided digital file. Its exact claim scope has **not** been assessed and this project must not claim patent novelty or freedom to operate on that basis.

## Research hypothesis worth testing

**H1:** For a matched event-vision classifier at a constrained streaming bandwidth, locally aggregated indexed events can reduce *total physical inference energy per correctly classified window*, relative to (i) dense fixed-rate loading and (ii) an equally clock-gated dense design, after accounting for CAM match cost, buffering, stalls, output serialization, and weight storage implementation.

This is only a research hypothesis, not an observed result. A null result is informative, especially if sparse scheduling adds enough overhead to offset skipped arithmetic.

## Design variables

- Encoder capacity E=8/16/32/64, occupancy distribution and partial flush frequency.
- Fraction of active tiles, event count skew, background activity, timestamp bins and thresholding.
- Output lanes per bank, physical RAM port budget, banking strategy and update conflict policies.
- Parallel INT8 multiplication vs actual 8-cycle signed bit-serial arithmetic.
- Precision using real narrower/packed operators, not merely truncating input data.
- Empty frame, burst-load, dead-time, input/output stalls and dropped-event tolerance.
- Quantization and accuracy on real subject-disjoint DVS datasets.

## Necessary experimental milestones

**M1 numerical:** report bit-exact parity over thousands of software traces. **Achieved locally** for 2,000 held-out synthetic windows, plus five Python tests.

**M2 RTL functional:** both Icarus and Verilator gate suites PASS, correctness under stalls, empty frames, table spills, signed values, reset. **Written, not executed here.**

**M3 synthesis and timing:** Yosys and FPGA vendor results, per-module area, memory inference, DSP use and a post-route fmax. **Not run.**

**M4 credible system:** connected board, real host and traceable energy/power estimates + onboard verification. **Not built.**

**M5 PhD-grade external validation:** real DVS Gesture/N-Cars/etc. data, subject-disjoint test splits, full pipeline accounting, accuracy-energy-latency Pareto fronts against appropriate baselines and quantitative analysis of coalescing overhead. **Not built.**

**M6 genuine SRAM-CIM claim:** implement and physically verify compute-capable memory macros with bitline/wordline arithmetic. **Not implemented.**

## Interview-ready presentation without overclaiming

> “I built a synthesizable, configurable, bank-local digital inference fabric with sparse event-addressed reads, an associative event coalescer, a two-layer quantized neural-network pipeline, and a bit-serial alternative. My reproducible software test achieves 99.8% on a deliberately synthetic motion classification problem, with exact integer equality across dense and sparse execution and an 83.65% reduction in counted bank-local lane reads/updates across both layers. I distinguish that traffic proxy from measured energy; physical CIM and FPGA PPA require a separate flow.”

Do not replace the final sentence with “I have built a real SRAM compute-in-memory chip.”
