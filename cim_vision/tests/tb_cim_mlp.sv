`timescale 1ns/1ps
module tb_cim_mlp;
    parameter bit BIT_SERIAL=1'b0;
    localparam integer FEATURES=128,HIDDEN=32,CLASSES=4,SAMPLES=24;
    logic clk=1'b0;
    always #5 clk=~clk;
    logic rst_n=0;
    logic cfg_valid=0,cfg_layer=0,cfg_is_bias=0;
    wire cfg_ready;
    logic [6:0] cfg_index=0;
    logic [5:0] cfg_output=0;
    logic signed [7:0] cfg_weight=0;
    logic signed [31:0] cfg_bias=0;
    logic in_valid=0,in_last=0;
    wire in_ready;
    logic [6:0] in_index=0;
    logic signed [7:0] in_value=0;
    wire out_valid,out_last,protocol_error;
    logic out_ready=0;
    wire signed [31:0] out_data;
    wire [1:0] out_class;
    reg [7:0] w1[0:FEATURES*HIDDEN-1];
    reg [7:0] w2[0:HIDDEN*CLASSES-1];
    reg [31:0] b1[0:HIDDEN-1];
    reg [31:0] b2[0:CLASSES-1];
    reg [7:0] vectors[0:SAMPLES*FEATURES-1];
    reg [31:0] scores[0:SAMPLES*CLASSES-1];
    integer cycles=0,recv=0, inference_start=0;
    integer sample_idx, last_idx, i, j;
    reg prev_stall=0;
    reg signed [31:0] prev_data;
    reg [1:0] prev_col;
    reg prev_last;
    cim_vision_mlp #(.BIT_SERIAL(BIT_SERIAL)) dut(
        .clk(clk),.rst_n(rst_n),.cfg_valid(cfg_valid),.cfg_ready(cfg_ready),
        .cfg_layer(cfg_layer),.cfg_is_bias(cfg_is_bias),
        .cfg_index(cfg_index),.cfg_output(cfg_output),
        .cfg_weight(cfg_weight),.cfg_bias(cfg_bias),
        .in_valid(in_valid),.in_ready(in_ready),.in_index(in_index),
        .in_value(in_value),.in_last(in_last),
        .out_valid(out_valid),.out_ready(out_ready),
        .out_data(out_data),.out_class(out_class),.out_last(out_last),
        .protocol_error(protocol_error)
    );
    // Deliberate consumer backpressure; all result data must be held stable.
    always @(negedge clk) begin
        if(rst_n) out_ready <= (cycles%7 != 0) && (cycles%7 != 1);
    end
    always @(posedge clk) begin
        if(rst_n) begin
            cycles<=cycles+1;
            if(cycles>3000000) $fatal(1,"TIMEOUT");
            if(protocol_error) $fatal(1,"RTL protocol_error");
            if(prev_stall) begin
                if(!out_valid || out_data!==prev_data || out_class!==prev_col || out_last!==prev_last)
                    $fatal(1,"out_valid/data/class/last changed under backpressure");
            end
            prev_stall <= out_valid && !out_ready;
            if(out_valid && !out_ready) begin
                prev_data<=out_data;
                prev_col<=out_class;
                prev_last<=out_last;
            end
            if(out_valid && out_ready) begin
                if(recv>=SAMPLES*CLASSES) $fatal(1,"extra output");
                if(out_class!==2'(recv%CLASSES))
                    $fatal(1,"class order got=%0d expected=%0d",out_class,recv%CLASSES);
                if(out_last!==(recv%CLASSES==CLASSES-1))
                    $fatal(1,"wrong out_last at %0d",recv);
                if(out_data!==$signed(scores[recv]))
                    $fatal(1,"score mismatch sample=%0d class=%0d got=%0d expected=%0d",recv/CLASSES,recv%CLASSES,out_data,$signed(scores[recv]));
                recv<=recv+1;
            end
        end
    end
    task automatic configure(input logic layer,input logic bias_en,
                             input logic [6:0] idx,input logic [5:0] col,
                             input logic signed [7:0] w,input logic signed [31:0] b);
        begin
            @(negedge clk);
            cfg_valid=1; cfg_layer=layer;cfg_is_bias=bias_en;
            cfg_index=idx;cfg_output=col;cfg_weight=w;cfg_bias=b;
            do @(posedge clk); while(!cfg_ready);
            @(negedge clk);cfg_valid=0;
        end
    endtask
    task automatic event_send(input logic [6:0] idx,
                              input logic signed [7:0] val,input logic last);
        begin
            @(negedge clk);
            in_valid=1;in_index=idx;in_value=val;in_last=last;
            do @(posedge clk); while(!in_ready);
            @(negedge clk);in_valid=0;in_last=0;
        end
    endtask
    initial begin
        $readmemh("models/w1.mem",w1);
        $readmemh("models/w2.mem",w2);
        $readmemh("models/b1.mem",b1);
        $readmemh("models/b2.mem",b2);
        $readmemh("models/vectors.mem",vectors);
        $readmemh("models/scores.mem",scores);
        repeat(5) @(negedge clk);
        rst_n=1;
        // Program every independent memory bank and every output bias.
        for(i=0;i<FEATURES;i=i+1)
            for(j=0;j<HIDDEN;j=j+1)
                configure(0,0,7'(i),6'(j),$signed(w1[i*HIDDEN+j]),0);
        for(j=0;j<HIDDEN;j=j+1)
            configure(0,1,0,6'(j),0,$signed(b1[j]));
        for(i=0;i<HIDDEN;i=i+1)
            for(j=0;j<CLASSES;j=j+1)
                configure(1,0,7'(i),6'(j),$signed(w2[i*CLASSES+j]),0);
        for(j=0;j<CLASSES;j=j+1)
            configure(1,1,0,6'(j),0,$signed(b2[j]));
        inference_start=cycles;
        // Dense versus sparse replay, including a truly empty sparse frame.
        for(sample_idx=0;sample_idx<SAMPLES;sample_idx=sample_idx+1) begin
            last_idx=-1;
            if(BIT_SERIAL==1'b0) begin
                // Both modes use identical numerical semantics; sparse mode is
                // selected at compile time below for separate runs.
            end
            for(i=0;i<FEATURES;i=i+1)
                if(vectors[sample_idx*FEATURES+i]!=0) last_idx=i;
            if($test$plusargs("DENSE")) begin
                for(i=0;i<FEATURES;i=i+1)
                    event_send(7'(i),$signed(vectors[sample_idx*FEATURES+i]),i==FEATURES-1);
            end else if(last_idx<0) begin
                event_send(0,0,1);
            end else begin
                for(i=0;i<FEATURES;i=i+1)
                    if(vectors[sample_idx*FEATURES+i]!=0)
                        event_send(7'(i),$signed(vectors[sample_idx*FEATURES+i]),i==last_idx);
            end
        end
        wait(recv==SAMPLES*CLASSES);
        repeat(3) @(posedge clk);
        $display("PASS CIM_MLP serial=%0d dense=%0d samples=%0d outputs=%0d cycles_with_programming=%0d",
            BIT_SERIAL,$test$plusargs("DENSE"),SAMPLES,recv,cycles);
        $display("PERF serial=%0d dense=%0d samples=%0d inference_cycles=%0d",
            BIT_SERIAL,$test$plusargs("DENSE"),SAMPLES,cycles-inference_start);
        $finish;
    end
endmodule
