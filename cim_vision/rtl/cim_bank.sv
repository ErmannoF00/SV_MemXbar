// Copyright (c) 2026. MIT license. Bank-local digital arithmetic next to
// inferred per-lane synchronous weight memory. This is NOT an SRAM-CIM cell.
module cim_bank #(
    parameter integer FEATURES = 128,
    parameter integer LANES = 4,
    parameter integer ACC_W = 32,
    parameter integer IDX_W = $clog2(FEATURES),
    parameter integer LANE_W = $clog2(LANES),
    parameter bit BIT_SERIAL = 1'b0
)(
    input  logic clk, rst_n,
    // Configuration is accepted only by owning layer when quiescent.
    input  logic cfg_en,
    input  logic cfg_is_bias,
    input  logic [IDX_W-1:0] cfg_index,
    input  logic [LANE_W-1:0] cfg_lane,
    input  logic signed [7:0] cfg_weight,
    input  logic signed [ACC_W-1:0] cfg_bias,
    // One synchronous read per lane; no cross-bank weight data bus.
    input  logic rd_en,
    input  logic [IDX_W-1:0] rd_index,
    input  logic frame_init,
    input  logic step_en,
    input  logic signed [7:0] step_value,
    input  logic [2:0] step_bit,
    output wire [LANES*ACC_W-1:0] scores
);
    genvar lane;
    generate for (lane=0; lane<LANES; lane=lane+1) begin : gen_lane
        // Each output lane owns an independent, single-read-port model-memory.
        // The memories are deliberately NOT reset, to permit RAM inference.
        logic signed [7:0] weights [0:FEATURES-1];
        logic signed [7:0] weight_q;
        logic signed [ACC_W-1:0] bias;
        logic signed [ACC_W-1:0] accumulator;
        logic signed [ACC_W-1:0] sext_weight;
        logic signed [ACC_W-1:0] shifted_weight;
        logic signed [15:0] product;
        assign scores[(lane*ACC_W)+:ACC_W] = accumulator;

        always_ff @(posedge clk) begin
            if (cfg_en && !cfg_is_bias && (cfg_lane == LANE_W'(lane)))
                weights[cfg_index] <= cfg_weight;
            if (rd_en)
                weight_q <= weights[rd_index];
        end
        always_comb begin
            sext_weight = {{(ACC_W-8){weight_q[7]}},weight_q};
            shifted_weight = sext_weight <<< step_bit;
            product = $signed(weight_q) * $signed(step_value);
        end
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                bias <= '0;
                accumulator <= '0;
            end else begin
                if (cfg_en && cfg_is_bias && (cfg_lane == LANE_W'(lane)))
                    bias <= cfg_bias;
                if (frame_init) begin
                    accumulator <= bias;
                end else if (step_en) begin
                    if (BIT_SERIAL) begin
                        // Two's-complement input bit 7 has NEGATIVE weight.
                        if (step_value[step_bit]) begin
                            if (step_bit == 3'd7)
                                accumulator <= accumulator - shifted_weight;
                            else
                                accumulator <= accumulator + shifted_weight;
                        end
                    end else begin
                        // Exact signed 8x8->16 product, sign-extended to ACC_W.
                        accumulator <= accumulator + $signed({{16{product[15]}}, product});
                    end
                end
            end
        end
    end endgenerate
endmodule
