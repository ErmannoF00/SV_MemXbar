PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
YOSYS ?= yosys
RTL = rtl/cim_bank.sv rtl/cim_layer.sv rtl/relu_q3.sv rtl/cim_vision_mlp.sv rtl/event_coalescer.sv rtl/event_cim_top.sv rtl/bitline_bool_cim.sv
.PHONY: test reference sim sim-all lint synth synth-generic regenerate clean demo bench bench-rtl
demo:
	$(PYTHON) tools/demo.py --sample 1
bench:
	$(PYTHON) tools/benchmark.py
reference:
	$(PYTHON) -m pytest -q tests/test_reference.py tests/test_coalescing_oracle.py tests/test_rtl_benchmark.py
sim: build
	$(IVERILOG) -g2012 -s tb_cim_mlp -o build/tb_mlp $(RTL) tests/tb_cim_mlp.sv
	$(VVP) build/tb_mlp
sim-all: build
	$(IVERILOG) -g2012 -s tb_cim_mlp -o build/tb_mlp $(RTL) tests/tb_cim_mlp.sv
	$(VVP) build/tb_mlp
	$(VVP) build/tb_mlp +DENSE
	$(IVERILOG) -g2012 -s tb_cim_mlp -Ptb_cim_mlp.BIT_SERIAL=1 -o build/tb_serial $(RTL) tests/tb_cim_mlp.sv
	$(VVP) build/tb_serial
	$(VVP) build/tb_serial +DENSE
	$(IVERILOG) -g2012 -s tb_coalescer -o build/tb_coalescer rtl/event_coalescer.sv tests/tb_coalescer.sv
	$(VVP) build/tb_coalescer
	$(IVERILOG) -g2012 -s tb_bool_cim -o build/tb_bool rtl/bitline_bool_cim.sv tests/tb_bool_cim.sv
	$(VVP) build/tb_bool
	$(IVERILOG) -g2012 -s tb_signed_core -o build/tb_signed rtl/cim_bank.sv rtl/cim_layer.sv tests/tb_signed_core.sv
	$(VVP) build/tb_signed
	$(IVERILOG) -g2012 -s tb_signed_core -Ptb_signed_core.BIT_SERIAL=1 -o build/tb_signed_serial rtl/cim_bank.sv rtl/cim_layer.sv tests/tb_signed_core.sv
	$(VVP) build/tb_signed_serial
	$(IVERILOG) -g2012 -s tb_event_top -o build/tb_e2e $(RTL) tests/tb_event_top.sv
	$(VVP) build/tb_e2e
	$(IVERILOG) -g2012 -s tb_event_top -Ptb_event_top.BIT_SERIAL=1 -o build/tb_e2e_serial $(RTL) tests/tb_event_top.sv
	$(VVP) build/tb_e2e_serial
lint:
	$(VERILATOR) --lint-only --timing -Wall -Werror-WIDTH -Werror-LATCH --top-module event_cim_top $(RTL)
synth: build
	$(YOSYS) -Q -T -l build/yosys.log -p 'read_verilog -sv $(RTL); hierarchy -check -top event_cim_top; proc; opt; check -assert; memory; opt; stat'
synth-generic: build
	$(YOSYS) -Q -T -l build/yosys_generic.log -p 'read_verilog -sv $(RTL); hierarchy -check -top event_cim_top; synth -top event_cim_top; check -assert; stat'
bench-rtl:
	$(PYTHON) tools/rtl_benchmark.py
regenerate:
	$(PYTHON) tools/train.py
build:
	mkdir -p build
clean:
	rm -rf build .pytest_cache tests/__pycache__ tools/__pycache__
test: reference sim-all lint synth
