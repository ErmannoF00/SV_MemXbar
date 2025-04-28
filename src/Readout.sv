module readout_layer #(
    parameter int WIDTH = 16,
    parameter int ACC_WIDTH = 32
)(
    input logic clk,
    input logic reset,
    input real analog_input,
    output logic [WIDTH-1:0] digital_out,
    output logic [ACC_WIDTH-1:0] acc_out
);
    assign digital_out = $rtoi(analog_input * (2**WIDTH - 1));

    logic [ACC_WIDTH-1:0] acc_reg;
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            acc_reg <= 0;
        else
            acc_reg <= acc_reg + digital_out;
    end

    assign acc_out = acc_reg;
endmodule
