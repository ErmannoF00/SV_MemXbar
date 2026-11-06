// Event-camera grid projection and per-window spatial-temporal aggregation.
// 128x128 event pixel address => 8x8 tiles x 2 time bins = 128 features.
// The sensor polarity is deliberately NOT represented in this first model.
// At end-of-window, emit (nonzero feature_index, count, last) without scanning
// all 128 features; only the valid entries of a 32-entry associative table.
// When full (or a count reaches 127), an internal PARTIAL FLUSH drains
// the table without asserting frame_last. The unaccepted event is retried.
// This guarantees exact results even across arbitrarily many table spills.
module event_coalescer #(
    parameter integer ENTRIES=32,
    parameter integer PTR_W=$clog2(ENTRIES)
)(
    input logic clk, rst_n,
    input logic evt_valid,
    output logic evt_ready,
    input logic [6:0] evt_x,evt_y,
    input logic evt_time_bin,
    input logic evt_last,
    input logic evt_marker_only, // delimiter for an empty window, not a real event
    output wire feature_valid,
    input logic feature_ready,
    output wire [6:0] feature_index,
    output wire signed [7:0] feature_count,
    output wire feature_last,
    output logic spill_occurred
);
    localparam [1:0] COLLECT=2'd0,EMIT=2'd1;
    logic [1:0] state;
    logic [6:0] keys[0:ENTRIES-1];
    logic signed [7:0] counts[0:ENTRIES-1];
    logic [ENTRIES-1:0] occupied;
    logic [PTR_W-1:0] emit_ptr;
    logic closing;
    logic match_found,empty_found;
    logic [PTR_W-1:0] match_ptr,empty_ptr;
    logic next_found,any_found;
    logic [6:0] incoming_feature;
    wire can_accept = match_found ? (counts[match_ptr] != 8'sd127) : empty_found;
    // The lower four coordinate bits are discarded by 16x16 binning.
    wire unused_subpixel_bits = ^{evt_x[3:0], evt_y[3:0]};
    assign incoming_feature = {evt_time_bin,evt_y[6:4],evt_x[6:4]};
    always_comb begin
        match_found=1'b0; empty_found=1'b0;
        match_ptr='0; empty_ptr='0;
        for (integer j=0; j<ENTRIES; j=j+1) begin
            if (occupied[j] && keys[j]==incoming_feature && !match_found) begin
                match_found=1'b1; match_ptr=PTR_W'(j);
            end
            if (!occupied[j] && !empty_found) begin
                empty_found=1'b1; empty_ptr=PTR_W'(j);
            end
        end
        evt_ready=(state==COLLECT) && (evt_marker_only || can_accept);
    end
    always_comb begin
        next_found=1'b0;
        any_found=1'b0;
        for(integer j=0;j<ENTRIES;j=j+1) begin
            if(occupied[j]) any_found=1'b1;
            if (PTR_W'(j) > emit_ptr && occupied[j]) next_found=1'b1;
        end
    end
    wire is_empty = !any_found;
    assign feature_valid=(state==EMIT) && (is_empty || occupied[emit_ptr]);
    assign feature_index=is_empty ? 7'd0 : keys[emit_ptr];
    assign feature_count=is_empty ? 8'sd0 : counts[emit_ptr];
    assign feature_last=closing && !next_found;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            occupied <= '0;
            state<=COLLECT;
            emit_ptr<='0;
            spill_occurred<=1'b0;
            closing<=1'b0;
            for (integer k=0;k<ENTRIES;k=k+1) begin
                keys[k]<='0;
                counts[k]<='0;
            end
        end else begin
            case(state)
                COLLECT: if(evt_valid && evt_ready) begin
                    if(!evt_marker_only) begin
                        if(match_found) begin
                            counts[match_ptr]<=counts[match_ptr]+8'sd1;
                        end else begin
                            occupied[empty_ptr]<=1'b1;
                            keys[empty_ptr]<=incoming_feature;
                            counts[empty_ptr]<=8'sd1;
                        end
                    end
                    if(evt_last) begin
                        closing<=1'b1;
                        emit_ptr<='0;
                        state<=EMIT;
                    end
                end else if (evt_valid && !evt_ready) begin
                    // Do not consume the full-table event; drain first.
                    closing<=1'b0;
                    spill_occurred<=1'b1;
                    emit_ptr<='0;
                    state<=EMIT;
                end
                EMIT: begin
                    if(feature_valid && feature_ready && !next_found) begin
                        state<=COLLECT;
                        occupied<='0;
                        emit_ptr<='0;
                        if(closing) spill_occurred<=1'b0;
                        closing<=1'b0;
                    end else if(feature_valid && feature_ready) begin
                        emit_ptr<=emit_ptr+PTR_W'(1);
                    end else if (!feature_valid) begin
                        emit_ptr<=emit_ptr+PTR_W'(1);
                    end
                end
                default: state<=COLLECT;
            endcase
        end
    end
endmodule
