`timescale 1ns/1ps
module tb_event_top;
    parameter bit BIT_SERIAL=0;
    localparam integer FEATURES=128,HIDDEN=32,CLASSES=4,SAMPLES=10;
    logic clk=0; always #5 clk=~clk;
    logic rst_n=0;
    logic evt_valid=0,evt_last=0,evt_time_bin=0,evt_marker_only=0;
    logic [6:0] evt_x=0,evt_y=0;
    wire evt_ready;
    logic cfg_valid=0,cfg_layer=0,cfg_is_bias=0;
    wire cfg_ready;
    logic [6:0] cfg_index=0;
    logic [5:0] cfg_output=0;
    logic signed [7:0] cfg_weight=0;
    logic signed [31:0] cfg_bias=0;
    wire out_valid,out_last,spill_occurred,protocol_error;
    logic out_ready=0;
    wire signed [31:0] out_data;
    wire [1:0] out_class;
    reg [7:0] w1[0:FEATURES*HIDDEN-1];
    reg [7:0] w2[0:HIDDEN*CLASSES-1];
    reg [31:0] b1[0:HIDDEN-1], b2[0:CLASSES-1];
    reg [7:0] vectors[0:24*FEATURES-1];
    reg [31:0] scores[0:24*CLASSES-1];
    integer cycles=0,recv=0,spills=0;
    integer sample_idx,last_idx,i,j,repeat_i,raw_count;
    event_cim_top #(.BIT_SERIAL(BIT_SERIAL),.ENTRIES(8)) dut (
        .clk(clk),.rst_n(rst_n),
        .evt_valid(evt_valid),.evt_ready(evt_ready),.evt_x(evt_x),.evt_y(evt_y),
        .evt_time_bin(evt_time_bin),.evt_last(evt_last),.evt_marker_only(evt_marker_only),
        .cfg_valid(cfg_valid),.cfg_ready(cfg_ready),.cfg_layer(cfg_layer),
        .cfg_is_bias(cfg_is_bias),.cfg_index(cfg_index),.cfg_output(cfg_output),
        .cfg_weight(cfg_weight),.cfg_bias(cfg_bias),
        .out_valid(out_valid),.out_ready(out_ready),.out_data(out_data),
        .out_class(out_class),.out_last(out_last),.spill_occurred(spill_occurred),
        .protocol_error(protocol_error)
    );
    always @(negedge clk) if(rst_n) out_ready=(cycles%7>=2);
    always @(posedge clk) if(rst_n) begin
        cycles<=cycles+1;
        if(cycles>3000000) $fatal(1,"end-to-end timeout");
        if(protocol_error) $fatal(1,"protocol_error");
        if(spill_occurred) spills<=spills+1;
        if(out_valid && out_ready) begin
            if(recv>=SAMPLES*CLASSES || out_class!==2'(recv%4) || out_last!==(recv%4==3))
                $fatal(1,"bad output framing");
            if(out_data!==$signed(scores[recv]))
                $fatal(1,"end-to-end score mismatch sample=%0d class=%0d got=%0d expected=%0d",recv/4,recv%4,out_data,$signed(scores[recv]));
            recv<=recv+1;
        end
    end
    task automatic configure(input logic layer,input logic bias_en,
                             input logic [6:0] idx,input logic [5:0] col,
                             input logic signed [7:0] w,input logic signed [31:0] b);
        @(negedge clk);
        cfg_valid=1;cfg_layer=layer;cfg_is_bias=bias_en;
        cfg_index=idx;cfg_output=col;cfg_weight=w;cfg_bias=b;
        do @(posedge clk); while(!cfg_ready);
        @(negedge clk);cfg_valid=0;
    endtask
    task automatic raw_event(input integer idx,input bit last,input bit empty);
        @(negedge clk);
        evt_valid=1;evt_marker_only=empty;
        evt_x=7'((idx%8)*16);evt_y=7'(((idx%64)/8)*16);
        evt_time_bin=1'(idx/64);evt_last=last;
        do @(posedge clk);while(!evt_ready);
        @(negedge clk);evt_valid=0;evt_last=0;evt_marker_only=0;
    endtask
    initial begin
        $readmemh("models/w1.mem",w1);$readmemh("models/w2.mem",w2);
        $readmemh("models/b1.mem",b1);$readmemh("models/b2.mem",b2);
        $readmemh("models/vectors.mem",vectors);$readmemh("models/scores.mem",scores);
        repeat(5) @(negedge clk);rst_n=1;
        for(i=0;i<FEATURES;i=i+1) for(j=0;j<HIDDEN;j=j+1)
            configure(0,0,7'(i),6'(j),$signed(w1[i*HIDDEN+j]),0);
        for(j=0;j<HIDDEN;j=j+1)
            configure(0,1,0,6'(j),0,$signed(b1[j]));
        for(i=0;i<HIDDEN;i=i+1) for(j=0;j<CLASSES;j=j+1)
            configure(1,0,7'(i),6'(j),$signed(w2[i*CLASSES+j]),0);
        for(j=0;j<CLASSES;j=j+1)
            configure(1,1,0,6'(j),0,$signed(b2[j]));
        // Each count is expanded back into a physical event. With ENTRIES=8
        // several windows MUST trigger internal partial flush and retry.
        for(sample_idx=0;sample_idx<SAMPLES;sample_idx=sample_idx+1) begin
            last_idx=-1;
            for(i=0;i<FEATURES;i=i+1)
                if(vectors[sample_idx*FEATURES+i]!=0) last_idx=i;
            if(last_idx<0) raw_event(0,1,1);
            else for(i=0;i<FEATURES;i=i+1) begin
                raw_count=vectors[sample_idx*FEATURES+i];
                for(repeat_i=0;repeat_i<raw_count;repeat_i=repeat_i+1)
                    raw_event(i,(i==last_idx && repeat_i==raw_count-1),0);
            end
        end
        wait(recv==SAMPLES*CLASSES);
        repeat(3) @(posedge clk);
        if(spills==0) $fatal(1,"expected internal spills not reached");
        $display("PASS END_TO_END serial=%0d samples=%0d outputs=%0d spill_seen_cycles=%0d cycles_including_cfg=%0d",
            BIT_SERIAL,SAMPLES,recv,spills,cycles);
        $finish;
    end
endmodule
