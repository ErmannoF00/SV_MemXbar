# EXAMPLE SYNTHESIS, NOT A BOARD PROOF.
# Digilent Arty A7-100T (Xilinx Artix-7): xc7a100tcsg324-1.
# No pin constraints, UART or implemented bitstream in this demonstration.
set top event_cim_top
set part_name xc7a100tcsg324-1
set files [glob rtl/*.sv]
read_verilog -sv $files
synth_design -top $top -part $part_name
create_clock -name clk_100mhz -period 10.000 [get_ports clk]
report_utilization -file build/vivado_utilization.txt
report_timing_summary -delay_type max -file build/vivado_timing.txt
write_checkpoint -force build/event_cim_synth.dcp
