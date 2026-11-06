// End-to-end FPGA-ready logical demo: event-camera tile encoder +
// associative feature coalescer + signed int8, two-layer inference in RTL.
// Clock is assumed synchronous throughout. No physical sensor interface.
module event_cim_top #(
    parameter bit BIT_SERIAL=1'b0,
    parameter integer ENTRIES=32
)(
    input logic clk,rst_n,
    input logic evt_valid,
    output wire evt_ready,
    input logic [6:0] evt_x,evt_y,
    input logic evt_time_bin,evt_last,evt_marker_only,
    input logic cfg_valid,
    output wire cfg_ready,
    input logic cfg_layer,cfg_is_bias,
    input logic [6:0] cfg_index,
    input logic [5:0] cfg_output,
    input logic signed [7:0] cfg_weight,
    input logic signed [31:0] cfg_bias,
    output wire out_valid,
    input logic out_ready,
    output wire signed [31:0] out_data,
    output wire [1:0] out_class,
    output wire out_last,
    output wire spill_occurred,protocol_error
);
    wire f_valid, f_ready, f_last;
    wire [6:0] f_index;
    wire signed [7:0] f_count;
    event_coalescer #(.ENTRIES(ENTRIES)) u_encoder(
        .clk(clk),.rst_n(rst_n),.evt_valid(evt_valid),.evt_ready(evt_ready),
        .evt_x(evt_x),.evt_y(evt_y),.evt_time_bin(evt_time_bin),.evt_last(evt_last),
        .evt_marker_only(evt_marker_only),
        .feature_valid(f_valid),.feature_ready(f_ready),
        .feature_index(f_index),.feature_count(f_count),
        .feature_last(f_last),.spill_occurred(spill_occurred)
    );
    cim_vision_mlp #(.BIT_SERIAL(BIT_SERIAL)) u_infer(
        .clk(clk),.rst_n(rst_n),.cfg_valid(cfg_valid),.cfg_ready(cfg_ready),
        .cfg_layer(cfg_layer),.cfg_is_bias(cfg_is_bias),
        .cfg_index(cfg_index),.cfg_output(cfg_output),
        .cfg_weight(cfg_weight),.cfg_bias(cfg_bias),
        .in_valid(f_valid),.in_ready(f_ready),.in_index(f_index),
        .in_value(f_count),.in_last(f_last),
        .out_valid(out_valid),.out_ready(out_ready),
        .out_data(out_data),.out_class(out_class),.out_last(out_last),
        .protocol_error(protocol_error)
    );
endmodule
