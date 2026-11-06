# Device model and architecture boundaries

## Original memristor source

The original SystemVerilog files remain under `src/` and `TB/`, at their existing paths, and are not rewritten by this integration. `AI_gen_img.jpg` also remains intact.

- `src/Memristor.sv` implements a behavioral two-terminal element with a voltage-dependent state variable `w`, linear resistance interpolation, clamping, and `current=voltage/R`. It is not an implementation of the full published JART VCM1 device equations, and does not implement TEAM threshold switching.
- `src/1T1R_Xbar.sv` instantiates a 64×64 grid of the behavioral memristors, but does not instantiate a MOS access transistor at every cell. `row_selected` and `col_selected` are not driven, and row/column output assignment lacks a proper reduction. The historical crossbar is therefore a starting model, not a validated electrical 1T1R array.
- `src/Readout.sv` provides a simple real-to-digital scaling and accumulator, not a transistor-level TIA or ADC.
- `src/AdLIF.sv` is a standalone real-valued adaptive integrate-and-fire model. It is not connected to the new digital event-classification accelerator.
- `TB/tb_memristor.sv` is empty in the original public snapshot. `TB/tb_neuron.sv` contains a minimal stimulus loop.

The **1T1R crossbar figure** shows a conventional reference topology: BL to resistive element to access transistor to SL, with WL gating the access transistor. It does *not* claim those physical devices or accurate current readout have been implemented by the original RTL.

## Added event-indexed digital inference

The independent `cim_vision/rtl/` design uses a 32-entry associative event coalescer and two INT8/INT32 neural-network layers (128→32→4). `cim_bank.sv` stores each lane's signed INT8 weights in a synchronous digital memory and implements MAC arithmetic adjacent to the memory. The separate `bitline_bool_cim.sv` module is a Boolean/popcount functional model, not a physical memory-bitline macro.

No analog 1T1R cells, transimpedance amplifiers, ADC circuits or device-programming pulses are in the new RTL datapath. Its matrix-vector results must not be described as simulated memristor-crossbar currents.

## Verification priorities

1. Preserve historical files and commits while adding new design under `cim_vision/`.
2. Run `make -C cim_vision reference`, `make -C cim_vision sim-all`, `make -C cim_vision lint`, `make -C cim_vision synth`, `make -C cim_vision bench-rtl` on a WSL/Linux machine with the HDL tools installed.
3. Evaluate the legacy memristor device separately against an actual JART or TEAM equation set if a corresponding device-level claim is desired.
4. Characterize actual memory energy, timing and bitline current using circuit models or technology macros before any physical CIM performance claim.
