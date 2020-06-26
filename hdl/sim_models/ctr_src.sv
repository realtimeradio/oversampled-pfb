`timescale 1ns/1ps
`default_nettype none

/*
  Up/down counter simulating ramp for 'processing' and 'natural' order ramp
  implements AXIS to support back pressure to hold count value
*/

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
  pass-through module simulating what the ready/valid interface of the top ospfb control
*/
   
module pt_ctr #(
  parameter MAX_CNT=32,
  parameter STP_CNT=24
) (
  input wire logic clk,
  input wire logic rst,
  axis.SLV s_axis,
  axis.MST m_axis
);

logic [$clog2(MAX_CNT)-1:0] ctr;

always_ff @(posedge clk)
  if (rst)
    ctr <= '0;
  else 
    ctr <= ctr + 1;

always_comb begin
  m_axis.tdata = s_axis.tdata; // Check the mst/slv axis handshake?
  m_axis.tvalid = 1;
  s_axis.tready = 1;
  if (ctr > STP_CNT-1) begin
    m_axis.tvalid = 0;
    s_axis.tready = 0;
  end
end
endmodule

// TOP combining source counter and pass through for example checking
module top #(
  parameter int MAX_CNT = 32,
  parameter int STP_CNT = 24,
  parameter string ORDER = "processing"
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis
);

  axis #(.WIDTH($clog2(MAX_CNT))) axis_src_to_pt();

  src_ctr #(
    .MAX_CNT(MAX_CNT),
    .ORDER(ORDER)
  ) src_ctr_inst (
    .clk(clk),
    .rst(rst),
    .m_axis(axis_src_to_pt)
  );
  
  pt_ctr #(
    .MAX_CNT(MAX_CNT),
    .STP_CNT(STP_CNT)
  ) pt_ctr_inst (
    .clk(clk),
    .rst(rst),
    .s_axis(axis_src_to_pt),
    .m_axis(m_axis)
  );

endmodule

/*
  Source counter test bench
*/

import alpaca_ospfb_utils_pkg::*;
module test_src_ctr;

parameter PERIOD = 10;
parameter MAX_CNT = 4;
parameter STP_CNT = 3;

logic clk, rst;
axis #(.WIDTH($clog2(MAX_CNT))) mst();

//src_ctr #(.MAX_CNT(MAX_CNT)) DUT (.clk(clk), .rst(rst), .m_axis(mst));

top #(
  .MAX_CNT(MAX_CNT),
  .STP_CNT(STP_CNT)
) DUT (
  .clk(clk),
  .rst(rst),
  .m_axis(mst)
);

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

  for (int k=0; k < 8; k++) begin

    for (int i=0; i < STP_CNT; i++) begin
      wait_cycles(1);
      $display(mst.print());
    end

    for (int i=0; i < (MAX_CNT-STP_CNT); i++) begin
      wait_cycles(1);
      $display(mst.print());
    end

    $display("");
  end

  $finish;
end

endmodule



