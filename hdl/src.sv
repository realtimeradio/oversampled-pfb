`timescale 1ns/1ps
`default_nettype none

module src_ctr #(
  parameter MAX_CNT=32,
  parameter string ORDER="processing"
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis
);

localparam logic [$clog2(MAX_CNT)-1:0] rst_val = (ORDER=="processing") ?  '1 : '0;
localparam logic [$clog2(MAX_CNT)-1:0] cnt_val = (ORDER=="processing") ? -1'sb1 : 1'b1;

logic [$clog2(MAX_CNT)-1:0] ctr;

always_ff @(posedge clk)
  if (rst)
    ctr <= rst_val;
  else begin
    if (m_axis.tready)
      ctr <= ctr + cnt_val;
    else
      ctr <= ctr;
  end

assign m_axis.tvalid = m_axis.tready;
assign m_axis.tdata = ctr;

endmodule

/*
  Source counter test bench
*/

import alpaca_ospfb_utils_pkg::*;
module test_src_ctr;

parameter PERIOD = 10;
parameter MAX_CNT = FFT_LEN;


logic clk, rst;
axis #(.WIDTH($clog2(MAX_CNT))) mst();

src_ctr #(.MAX_CNT(MAX_CNT)) DUT (.clk(clk), .rst(rst), .m_axis(mst));

initial begin
  clk <= 0;
  forever #(PERIOD/2)
    clk = ~clk;
end

task wait_cycles(input int cycles);
  repeat(cycles)
    @(posedge clk);
endtask

initial begin
  rst <= 1;
  @(posedge clk);
  @(negedge clk); rst = 0; mst.tready = 1;

  for (int i=0; i < MAX_CNT+1; i++) begin
    $display(mst.tdata);
    wait_cycles(1);
    #1ns;
  end
  $finish;
end

endmodule



