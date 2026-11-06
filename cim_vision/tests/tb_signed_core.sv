`timescale 1ns/1ps
module tb_signed_core;
  parameter bit BIT_SERIAL=0;
  logic clk=0;always #5 clk=~clk;
  logic rst_n=0,cfg_valid=0,cfg_is_bias=0;
  wire cfg_ready,in_ready,out_valid,out_last,protocol_error;
  logic [1:0] cfg_index=0,cfg_output=0,in_index=0;
  logic signed [7:0] cfg_weight=0,in_value=0;
  logic signed [31:0] cfg_bias=0;
  logic in_valid=0,in_last=0,out_ready=0;
  wire signed [31:0] out_data;
  wire [1:0] out_col;
  logic signed [7:0] weights[0:15];
  logic signed [31:0] bias[0:3],expected_scores[0:3];
  integer out_cnt=0,cycles=0,i,j;
  cim_layer #(.FEATURES(4),.OUTPUTS(4),.BANK_LANES(4),.BIT_SERIAL(BIT_SERIAL)) dut(
    .clk(clk),.rst_n(rst_n),.cfg_valid(cfg_valid),.cfg_ready(cfg_ready),
    .cfg_is_bias(cfg_is_bias),.cfg_index(cfg_index),.cfg_output(cfg_output),
    .cfg_weight(cfg_weight),.cfg_bias(cfg_bias),
    .in_valid(in_valid),.in_ready(in_ready),.in_index(in_index),
    .in_value(in_value),.in_last(in_last),.out_valid(out_valid),
    .out_ready(out_ready),.out_data(out_data),.out_col(out_col),
    .out_last(out_last),.protocol_error(protocol_error));
  always @(negedge clk) if(rst_n) out_ready=(cycles%4>=1);
  always @(posedge clk) if(rst_n) begin
    cycles<=cycles+1;
    if(cycles>10000) $fatal(1,"timeout");
    if(protocol_error) $fatal(1,"bad protocol");
    if(out_valid && out_ready) begin
      if(out_cnt>=4 || out_col!==2'(out_cnt) || out_data!==expected_scores[out_cnt] || out_last!==(out_cnt==3))
         $fatal(1,"signed test mismatch idx=%0d expected=%0d got=%0d",out_cnt,expected_scores[out_cnt],out_data);
      out_cnt<=out_cnt+1;
    end
  end
  task automatic cfg(input integer idx,input integer col,input integer w,input bit is_bias);
    @(negedge clk);cfg_valid=1;cfg_is_bias=is_bias;
    cfg_index=2'(idx);cfg_output=2'(col);
    cfg_weight=8'(w);cfg_bias=bias[col];
    do @(posedge clk);while(!cfg_ready);
    @(negedge clk);cfg_valid=0;
  endtask
  task automatic push(input integer idx,input integer value,input bit last);
    @(negedge clk);in_valid=1;in_index=2'(idx);in_value=8'(value);in_last=last;
    do @(posedge clk);while(!in_ready);
    @(negedge clk);in_valid=0;in_last=0;
  endtask
  initial begin
    // row-major in feature then output. Signed extremes are intentional.
    weights[0]=-128;weights[1]=-1;weights[2]=1;weights[3]=127;
    weights[4]=127;weights[5]=1;weights[6]=-1;weights[7]=-128;
    weights[8]=-1;weights[9]=-128;weights[10]=127;weights[11]=1;
    weights[12]=0;weights[13]=0;weights[14]=0;weights[15]=0;
    bias[0]=0;bias[1]=12;bias[2]=-14;bias[3]=100;
    expected_scores[0]=32514;expected_scores[1]=395;expected_scores[2]=-396;expected_scores[3]=-32413;
    repeat(5) @(negedge clk);rst_n=1;
    for(i=0;i<4;i=i+1) for(j=0;j<4;j=j+1)
      cfg(i,j,weights[i*4+j],0);
    for(j=0;j<4;j=j+1) cfg(0,j,0,1);
    push(0,-128,0);push(1,127,0);push(2,-1,1);
    wait(out_cnt==4);
    $display("PASS signed extrema bit_serial=%0d",BIT_SERIAL);
    $finish;
  end
endmodule
