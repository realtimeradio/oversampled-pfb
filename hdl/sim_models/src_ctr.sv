`timescale 1ns/1ps
`default_nettype none

/*
  Up/down counter simulating ramp for 'processing' and 'natural' order ramp
  implements AXIS to support back pressure to hold count value
*/

module src_ctr #(
  parameter WIDTH=16,
  parameter MAX_CNT=32,
  parameter string ORDER="processing"
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis
);

localparam logic [WIDTH-1:0] rst_val = (ORDER=="processing") ?  MAX_CNT-1 : '0;
localparam logic [WIDTH-1:0] cnt_val = (ORDER=="processing") ? -1'sb1 : 1'b1;

logic [WIDTH-1:0] dout;

// only needed for processing order source
logic [WIDTH-1:0] highVal;
logic en;

always_ff @(posedge clk)
  if (rst)
    highVal <= MAX_CNT;
  else if (m_axis.tready)
    if (dout[$clog2(MAX_CNT)-1:0] == 1)
      highVal <= highVal + MAX_CNT;
    else
      highVal <= highVal;

always_ff @(posedge clk)
  if (rst)
    dout <= rst_val;
  else if (m_axis.tready)
    if (dout[$clog2(MAX_CNT)-1:0] == 0)
      dout <= highVal - 1;
    else
      dout <= dout + cnt_val;
  else
    dout <= dout;

assign m_axis.tvalid = m_axis.tready;
assign m_axis.tdata = dout;

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
  parameter int WIDTH = 16,
  parameter int MAX_CNT = 32,
  parameter int STP_CNT = 24,
  parameter string ORDER = "processing"
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis
);

  axis #(.WIDTH(WIDTH)) axis_src_to_pt();

  src_ctr #(
    .WIDTH(WIDTH),
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

parameter MAX_CNT = 8;
parameter STP_CNT = 6;

logic clk, rst;
axis #(.WIDTH(WIDTH)) mst();

//src_ctr #(.MAX_CNT(MAX_CNT)) DUT (.clk(clk), .rst(rst), .m_axis(mst));

top #(
  .WIDTH(WIDTH),
  .MAX_CNT(MAX_CNT),
  .STP_CNT(STP_CNT),
  .ORDER("processing")
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



