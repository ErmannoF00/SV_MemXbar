// AdLIF Neuron Implementation
module adlif_neuron (
    input real input_current,     // Input current (nA)
    input real time_step,         // Time step for simulation (ms)
    output logic spike,           // Spike output
    output real membrane_voltage, // Membrane potential (V)
    output real threshold         // Adaptive threshold (V)
);
    // Parameters
    parameter real V_rest = -70.0;      // Resting potential (mV)
    parameter real V_reset = -65.0;     // Reset potential (mV)
    parameter real V_th_base = -50.0;   // Baseline threshold (mV)
    parameter real tau_m = 20.0;        // Membrane time constant (ms)
    parameter real tau_th = 100.0;      // Threshold decay time constant (ms)
    parameter real C_m = 1.0;           // Membrane capacitance (uF)
    parameter real beta = 5.0;          // Threshold adaptation factor (mV)

    // Internal state variables
    real V;           // Membrane potential
    real V_th;        // Adaptive threshold
    real time_since_spike; // Time since last spike

    // Initialize values
    initial begin
        V = V_rest;
        V_th = V_th_base;
        time_since_spike = 0.0;
        spike = 0;
    end

    // Compute dynamics at each time step
    always @(input_current or time_step) begin
        // Update threshold decay
        V_th = V_th_base + (V_th - V_th_base) * exp(-time_step / tau_th);

        // Update membrane potential dynamics
        V = V + time_step * ((-1 * (V - V_rest) / tau_m) + (input_current / C_m));

        // Check for spiking condition
        if (V >= V_th) begin
            spike = 1;
            V = V_reset;                  // Reset membrane potential
            V_th = V_th + beta;           // Increase threshold due to spike
            time_since_spike = 0.0;       // Reset spike time
        end else begin
            spike = 0;
        end
    end

    // Outputs
    assign membrane_voltage = V;
    assign threshold = V_th;

endmodule
