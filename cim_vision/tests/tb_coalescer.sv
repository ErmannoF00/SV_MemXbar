`timescale 1ns/1ps
module tb_coalescer;
    logic clk=0; always #5 clk=~clk;
    logic rst_n=0,evt_valid=0,evt_last=0,evt_marker_only=0;
    logic [6:0] evt_x=0,evt_y=0;
    logic evt_time_bin=0;
    wire evt_ready, feature_valid,feature_last,spill_occurred;
    logic feature_ready=0;
    wire [6:0] feature_index;
    wire signed [7:0] feature_count;
    integer expected[0:127];
    integer observed[0:127];
    integer cycles=0,observed_last=0,i,j;
    reg prev_stall=0;
    reg [6:0] prev_index;
    reg signed [7:0] prev_count;
    reg prev_last;
    event_coalescer #(.ENTRIES(8)) dut(
        .clk(clk),.rst_n(rst_n),.evt_valid(evt_valid),.evt_ready(evt_ready),
        .evt_x(evt_x),.evt_y(evt_y),.evt_time_bin(evt_time_bin),
        .evt_last(evt_last),.evt_marker_only(evt_marker_only),
        .feature_valid(feature_valid),.feature_ready(feature_ready),
        .feature_index(feature_index),.feature_count(feature_count),
        .feature_last(feature_last),.spill_occurred(spill_occurred)
    );
    always @(negedge clk) begin
        if(rst_n) feature_ready=(cycles%5!=2);
    end
    always @(posedge clk) if(rst_n) begin
        cycles<=cycles+1;
        if(cycles>200000) $fatal(1,"coalescer timeout");
        if(prev_stall && (!feature_valid || feature_index!==prev_index || feature_count!==prev_count || feature_last!==prev_last))
            $fatal(1,"coalescer output changed during stall");
        prev_stall<=feature_valid && !feature_ready;
        if(feature_valid && !feature_ready) begin
            prev_index<=feature_index;prev_count<=feature_count;prev_last<=feature_last;
        end
        if(feature_valid && feature_ready) begin
            if(feature_count<0) $fatal(1,"negative count");
            observed[feature_index]<=observed[feature_index]+$signed(feature_count);
            if(feature_last) observed_last<=observed_last+1;
        end
    end
    task automatic send(input integer idx,input bit last);
        begin
            @(negedge clk);
            evt_valid=1;
            evt_x=7'((idx%8)*16);evt_y=7'(((idx/8)%8)*16);
            evt_time_bin=1'(idx/64);evt_last=last;
            do @(posedge clk); while(!evt_ready);
            @(negedge clk);evt_valid=0;evt_last=0;
        end
    endtask
    initial begin
        for(i=0;i<128;i=i+1) begin expected[i]=0;observed[i]=0; end
        repeat(5) @(negedge clk);rst_n=1;
        // Force several 8-entry CAM capacity spills and an INT8-count spill.
        for(i=0;i<40;i=i+1) begin
            send(i,0);
            expected[i]=expected[i]+1;
        end
        for(i=0;i<131;i=i+1) begin
            send(0,i==130);
            expected[0]=expected[0]+1;
        end
        wait(observed_last==1);
        repeat(3) @(posedge clk);
        for(j=0;j<128;j=j+1)
            if(expected[j]!==observed[j])
                $fatal(1,"coalescing mismatch idx=%0d actual=%0d expected=%0d",j,observed[j],expected[j]);
        $display("PASS COALESCER entries=8 raw_events=171 unique=40, spills, 131 repeated events; cycles=%0d",cycles);
        $finish;
    end
endmodule
