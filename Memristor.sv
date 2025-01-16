// Memristor Model (Converted to SystemVerilog)
module memristor (
    input real voltage,           // Voltage applied across the memristor (V)
    output real current,          // Current through the memristor (A)
    output real memristance       // Memristance of the device (Ohms)
);
    // Parameters
    parameter real R_on = 100.0;      // Low resistance state (Ohms)
    parameter real R_off = 16000.0;   // High resistance state (Ohms)
    parameter real D = 10e-9;         // Thickness of the memristor (m)
    parameter real mu_v = 1e-10;      // Mobility of dopants (m^2/sV)

    // Internal state variables
    real w;           // Width of the doped region (m)
    real R;           // Current resistance (Ohms)

    // Initialize values
    initial begin
        w = D / 2;    // Start with half the device doped
        R = R_off;
    end

    // Update memristance based on voltage
    always @(voltage) begin
        // Update the doped region width
        w = w + mu_v * voltage;

        // Clamp w between 0 and D
        if (w > D) w = D;
        if (w < 0) w = 0;

        // Calculate the resistance
        R = R_on * (w / D) + R_off * (1 - w / D);
    end

    // Outputs
    assign memristance = R;
    assign current = voltage / R;

endmodule
