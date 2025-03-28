module tb_adlif_neuron;
    real i;
    real dt = 1.0;
    logic s;
    real v;
    real th;

    adlif_neuron n0 (
        .input_current(i),
        .time_step(dt),
        .spike(s),
        .membrane_voltage(v),
        .threshold(th)
    );

    initial begin
        i = 10.0;
        repeat (20) begin
            #1;
            $display("%0t\tCurrent=%0f\tVoltage=%0f\tThreshold=%0f\tSpike=%0b", $time, i, v, th, s);
        end
    end
endmodule
