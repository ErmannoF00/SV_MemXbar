// DIGITAL-CIM FUNCTIONAL EXPERIMENT (not a fabricated SRAM bitcell).
// Ternary {-1,0,+1} weights retained in local positive/negative bitplanes.
// Popcount(activation AND positive_wordline) minus the corresponding negative
// popcount is computed inside the bank interface, without exporting weights.
// Physically mapping the AND gates to SRAM peripheral/bitline circuitry would
// require a custom memory macro, physical design and circuit characterization.
module bitline_bool_cim #(
    parameter integer FEATURES=16,
    parameter integer OUTPUTS=4,
    parameter integer FEAT_W=$clog2(FEATURES),
    parameter integer OUT_W=$clog2(OUTPUTS),
    parameter integer SCORE_W=16
)(
    input logic clk,rst_n,
    input logic cfg_valid,
    output wire cfg_ready,
    input logic [FEAT_W-1:0] cfg_feature,
    input logic [OUT_W-1:0] cfg_output,
    input logic signed [1:0] cfg_weight, // only -1,0,+1 permitted
    input logic start,
    output wire start_ready,
    input logic [FEATURES-1:0] activity,
    output wire out_valid,
    input logic out_ready,
    output wire signed [SCORE_W-1:0] out_score,
    output wire [OUT_W-1:0] out_col,
    output wire out_last,
    output logic config_error
);
    logic [FEATURES-1:0] w_positive [0:OUTPUTS-1];
    logic [FEATURES-1:0] w_negative [0:OUTPUTS-1];
    logic signed [SCORE_W-1:0] partial [0:OUTPUTS-1];
    logic busy;
    logic [OUT_W-1:0] col;
    assign cfg_ready=!busy && !start;
    assign start_ready=!busy && !cfg_valid;
    assign out_valid=busy;
    assign out_score=partial[col];
    assign out_col=col;
    assign out_last=(col==OUT_W'(OUTPUTS-1));
    function automatic integer count_ones(input logic [FEATURES-1:0] bits);
        integer total;
        begin
            total=0;
            for(integer k=0;k<FEATURES;k=k+1)
                if(bits[k]) total=total+1;
            count_ones=total;
        end
    endfunction
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy<=0;col<='0;config_error<=0;
            for(integer c=0;c<OUTPUTS;c=c+1) begin
                w_positive[c]<='0;
                w_negative[c]<='0;
                partial[c]<='0;
            end
        end else begin
            if(cfg_valid && cfg_ready) begin
                if(cfg_weight != -2'sd1 && cfg_weight != 2'sd0 && cfg_weight != 2'sd1)
                    config_error<=1'b1;
                else begin
                    w_positive[cfg_output][cfg_feature]<=(cfg_weight==2'sd1);
                    w_negative[cfg_output][cfg_feature]<=(cfg_weight==-2'sd1);
                end
            end
            if(start && start_ready) begin
                for(integer c=0;c<OUTPUTS;c=c+1) begin
                    partial[c]<=SCORE_W'(count_ones(activity & w_positive[c])
                                              -count_ones(activity & w_negative[c]));
                end
                col<='0;
                busy<=1'b1;
            end else if(out_valid && out_ready) begin
                if(out_last) busy<=1'b0;
                else col<=col+OUT_W'(1);
            end
        end
    end
endmodule
