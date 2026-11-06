// First-layer accumulators are Q5; unsigned hidden activations are Q3.
// ReLU, positive half-up division by 4, saturation to signed INT8 0..127.
module relu_q3(
    input  logic signed [31:0] acc,
    output logic signed [7:0] activation
);
    always_comb begin
        if (acc <= 0) activation=8'sd0;
        else if (acc >= 32'sd506) activation=8'sd127;
        else activation = 8'((acc + 32'sd2) >>> 2);
    end
endmodule
