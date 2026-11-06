// Full RTL 128->32->4 inference with two isolated, programmable weight banks.
// No host computation between layers. Per-frame argmax is left to host.
module cim_vision_mlp #(
    parameter integer FEATURES = 128,
    parameter integer HIDDEN = 32,
    parameter integer CLASSES = 4,
    parameter integer BANK_LANES = 4,
    parameter bit BIT_SERIAL = 1'b0
)(
    input logic clk, rst_n,
    input logic cfg_valid,
    output wire cfg_ready,
    input logic cfg_layer,
    input logic cfg_is_bias,
    input logic [6:0] cfg_index,
    input logic [5:0] cfg_output,
    input logic signed [7:0] cfg_weight,
    input logic signed [31:0] cfg_bias,
    input logic in_valid,
    output wire in_ready,
    input logic [6:0] in_index,
    input logic signed [7:0] in_value,
    input logic in_last,
    output wire out_valid,
    input logic out_ready,
    output wire signed [31:0] out_data,
    output wire [1:0] out_class,
    output wire out_last,
    output wire protocol_error
);
    // Concrete demo interface: features=128, hidden=32, classes=4.
    localparam [1:0] TOP_IDLE=2'd0,TOP_FEED=2'd1,TOP_DRAIN=2'd2;
    logic [1:0] state;
    wire l1_cfg_ready,l2_cfg_ready;
    wire l1_in_ready,l2_in_ready;
    wire l1_out_valid,l1_out_last,l2_out_last;
    wire [4:0] hidden_col;
    wire signed [31:0] hidden_acc;
    wire signed [7:0] hidden_q;
    wire l1_protocol_error,l2_protocol_error;
    logic cfg_error;
    wire bad_cfg = (cfg_layer && ((cfg_output >= 6'd4) || (!cfg_is_bias && cfg_index >= 7'd32)))
                 || (!cfg_layer && cfg_output >= 6'd32);
    wire can_feed = (state==TOP_IDLE || state==TOP_FEED) && !cfg_valid;
    wire l1_feed_valid = in_valid && can_feed;
    assign in_ready = can_feed && l1_in_ready;
    assign cfg_ready = (state==TOP_IDLE) && (bad_cfg || (cfg_layer ? l2_cfg_ready : l1_cfg_ready));
    assign protocol_error = l1_protocol_error || l2_protocol_error || cfg_error;
    relu_q3 u_quant(.acc(hidden_acc),.activation(hidden_q));

    cim_layer #(.FEATURES(FEATURES),.OUTPUTS(HIDDEN),
                .BANK_LANES(BANK_LANES),.BIT_SERIAL(BIT_SERIAL)) u_hidden(
        .clk(clk),.rst_n(rst_n),
        .cfg_valid(cfg_valid && !cfg_layer && !bad_cfg && state==TOP_IDLE),
        .cfg_ready(l1_cfg_ready),.cfg_is_bias(cfg_is_bias),
        .cfg_index(cfg_index),.cfg_output(cfg_output[4:0]),
        .cfg_weight(cfg_weight),.cfg_bias(cfg_bias),
        .in_valid(l1_feed_valid),.in_ready(l1_in_ready),
        .in_index(in_index),.in_value(in_value),.in_last(in_last),
        .out_valid(l1_out_valid),.out_ready(l2_in_ready),
        .out_data(hidden_acc),.out_col(hidden_col),.out_last(l1_out_last),
        .protocol_error(l1_protocol_error)
    );
    cim_layer #(.FEATURES(HIDDEN),.OUTPUTS(CLASSES),
                .BANK_LANES(BANK_LANES),.BIT_SERIAL(BIT_SERIAL)) u_classifier(
        .clk(clk),.rst_n(rst_n),
        .cfg_valid(cfg_valid && cfg_layer && !bad_cfg && state==TOP_IDLE),
        .cfg_ready(l2_cfg_ready),.cfg_is_bias(cfg_is_bias),
        .cfg_index(cfg_index[4:0]),.cfg_output(cfg_output[1:0]),
        .cfg_weight(cfg_weight),.cfg_bias(cfg_bias),
        .in_valid(l1_out_valid),.in_ready(l2_in_ready),
        .in_index(hidden_col),.in_value(hidden_q),.in_last(l1_out_last),
        .out_valid(out_valid),.out_ready(out_ready),
        .out_data(out_data),.out_col(out_class),.out_last(l2_out_last),
        .protocol_error(l2_protocol_error)
    );
    assign out_last = l2_out_last;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=TOP_IDLE;
            cfg_error<=1'b0;
        end else begin
          if (cfg_valid && cfg_ready && bad_cfg) cfg_error<=1'b1;
          case(state)
            TOP_IDLE: if(l1_feed_valid) state<=TOP_FEED;
            TOP_FEED: if (in_valid && in_ready && in_last) state<=TOP_DRAIN;
            TOP_DRAIN: if(out_valid && out_ready && out_last) state<=TOP_IDLE;
            default: state<=TOP_IDLE;
          endcase
        end
    end
endmodule
