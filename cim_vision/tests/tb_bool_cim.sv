`timescale 1ns/1ps
module tb_bool_cim;
  logic clk=0; always #5 clk=~clk;
  logic rst_n=0,cfg_valid=0,start=0;
  wire cfg_ready,start_ready,out_valid,out_last,config_error;
  logic [3:0] cfg_feature=0;
  logic [1:0] cfg_output=0;
  logic signed [1:0] cfg_weight=0;
  logic [15:0] activity=0;
  logic out_ready=0;
  wire signed [15:0] out_score;
  wire [1:0] out_col;
  integer seen=0,cyc=0;
  bit stalled=0;
  reg signed [15:0] saved;
  bitline_bool_cim dut(.*);
  always @(negedge clk) if(rst_n) out_ready=(cyc%3!=0);
  always @(posedge clk) if(rst_n) begin
    cyc<=cyc+1;
    if(cyc>1000) $fatal(1,"timeout");
    if(config_error) $fatal(1,"bad weight");
    if(stalled && (!out_valid || out_score!==saved)) $fatal(1,"stall failed");
    stalled<=out_valid && !out_ready;
    if(out_valid && !out_ready) saved<=out_score;
    if(out_valid && out_ready) begin
      case(seen)
      0: if(out_score!=2) $fatal(1,"score0 expected2 got%0d",out_score);
      1: if(out_score!=-1) $fatal(1,"score1 expected-1 got%0d",out_score);
      2: if(out_score!=0) $fatal(1,"score2 expected0 got%0d",out_score);
      3: if(out_score!=0 || !out_last) $fatal(1,"score3 wrong");
      endcase
      seen<=seen+1;
    end
  end
  task automatic weight(input integer idx,input integer col,input integer w);
    @(negedge clk);
    cfg_valid=1;cfg_feature=4'(idx);cfg_output=2'(col);cfg_weight=2'(w);
    do @(posedge clk);while(!cfg_ready);
    @(negedge clk);cfg_valid=0;
  endtask
  initial begin
    repeat(4) @(negedge clk);rst_n=1;
    weight(0,0,1);weight(1,0,1);weight(2,0,-1); // 2 positives, one absent negative
    weight(0,1,-1);
    @(negedge clk);activity=16'b0000_0000_0000_0011;start=1;
    do @(posedge clk);while(!start_ready);
    @(negedge clk);start=0;
    wait(seen==4);
    $display("PASS BOOL CIM bitline AND/popcount, stalls");$finish;
  end
endmodule
