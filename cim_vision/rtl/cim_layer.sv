// Indexed sparse/dense MVM. Same hardware and same weights for both modes:
// dense sends all I (index,value) records, sparse sends only nonzero records.
// Serial mode uses eight in-bank shift/add microsteps per record.
module cim_layer #(
    parameter integer FEATURES = 128,
    parameter integer OUTPUTS = 32,
    parameter integer BANK_LANES = 4,
    parameter integer ACC_W = 32,
    parameter bit BIT_SERIAL = 1'b0,
    parameter integer IDX_W = $clog2(FEATURES),
    parameter integer OUT_W = $clog2(OUTPUTS)
)(
    input logic clk, rst_n,
    input logic cfg_valid,
    output wire cfg_ready,
    input logic cfg_is_bias,
    input logic [IDX_W-1:0] cfg_index,
    input logic [OUT_W-1:0] cfg_output,
    input logic signed [7:0] cfg_weight,
    input logic signed [ACC_W-1:0] cfg_bias,
    input logic in_valid,
    output wire in_ready,
    input logic [IDX_W-1:0] in_index,
    input logic signed [7:0] in_value,
    input logic in_last,
    output wire out_valid,
    input logic out_ready,
    output wire signed [ACC_W-1:0] out_data,
    output wire [OUT_W-1:0] out_col,
    output wire out_last,
    output logic protocol_error
);
    localparam integer BANKS=OUTPUTS/BANK_LANES;
    localparam integer LANE_W=$clog2(BANK_LANES);
    localparam logic [1:0] IDLE=2'd0, COLLECT=2'd1, EXEC=2'd2, EMIT=2'd3;
    logic [1:0] state;
    logic [OUT_W-1:0] emit_idx;
    logic signed [7:0] held_value;
    logic held_last;
    logic [2:0] bit_idx;
    wire accepted = in_valid && in_ready;
    wire initialize = (state==IDLE) && in_valid && !cfg_valid;
    wire read_enable = accepted;
    wire step_enable = (state==EXEC);
    wire [BANKS*BANK_LANES*ACC_W-1:0] all_scores;

    assign cfg_ready = (state==IDLE) && !in_valid;
    assign in_ready = (state==COLLECT);
    assign out_valid = (state==EMIT);
    assign out_data = $signed(all_scores[emit_idx*ACC_W +:ACC_W]);
    assign out_col = emit_idx;
    assign out_last = (emit_idx==OUT_W'(OUTPUTS-1));

    genvar bank;
    generate for (bank=0; bank<BANKS; bank=bank+1) begin : gen_bank
        // BANK_LANES is a power of two (4 in the supplied design).
        wire bank_cfg = cfg_valid && cfg_ready &&
                        ((cfg_output >> LANE_W) == OUT_W'(bank));
        cim_bank #(.FEATURES(FEATURES),.LANES(BANK_LANES),.ACC_W(ACC_W),
                   .IDX_W(IDX_W),.LANE_W(LANE_W),.BIT_SERIAL(BIT_SERIAL)) u_bank(
            .clk(clk),.rst_n(rst_n),.cfg_en(bank_cfg),
            .cfg_is_bias(cfg_is_bias),.cfg_index(cfg_index),
            .cfg_lane(cfg_output[LANE_W-1:0]),
            .cfg_weight(cfg_weight),.cfg_bias(cfg_bias),
            .rd_en(read_enable),.rd_index(in_index),.frame_init(initialize),
            .step_en(step_enable),.step_value(held_value),.step_bit(bit_idx),
            .scores(all_scores[(bank*BANK_LANES)*ACC_W +: BANK_LANES*ACC_W])
        );
    end endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            emit_idx <= '0;
            held_value <= '0;
            held_last <= 1'b0;
            bit_idx <= '0;
            protocol_error <= 1'b0;
        end else begin
            case(state)
                IDLE: if (initialize) state<=COLLECT;
                COLLECT: if (accepted) begin
                    held_value <= in_value;
                    held_last <= in_last;
                    bit_idx <= '0;
                    if ({1'b0, in_index} >= (IDX_W+1)'(FEATURES)) protocol_error<=1'b1;
                    state<=EXEC;
                end
                EXEC: if (!BIT_SERIAL || bit_idx==3'd7) begin
                    if (held_last) begin
                        emit_idx<='0;
                        state<=EMIT;
                    end else begin
                        state<=COLLECT;
                    end
                end else begin
                    bit_idx <= bit_idx + 3'd1;
                end
                EMIT: if (out_ready) begin
                    if (out_last) state<=IDLE;
                    else emit_idx<=emit_idx+OUT_W'(1);
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
