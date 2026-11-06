# Relationship to the original memristor repository

The parent repository's existing `src/` and `TB/` remain unchanged. The README previously described a JART VCM1-inspired memristor model and an AdLIF neuron; the new `cim_vision/` subsystem instead implements inferred digital memories and signed integer arithmetic. The two implementations do **not** share a physical memory macro, electrical device model or validated energy numbers. No interface between original analog-inspired model and the digital accelerator is implemented. Preserve any team contributors and original source attributions through the existing Git history.

An actual TEAM / VTEAM memristor device model, if required, must be verified against the source equations before labeling it as such; do not automatically rename the existing JART-inspired model.

Prepared regression: 11 Python tests, eight or more Icarus simulations across dense/sparse, serial/parallel, coalescer/Boolean-CIM and end-to-end, Verilator lint, Yosys structural check, and a separate dense/sparse RTL-cycle comparison. The external HDL gates remain unverified until run in WSL and CI.
