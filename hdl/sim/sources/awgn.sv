`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/**************************************************
  AWGN
***************************************************/

module awgn #(
  parameter int SEED=123456789,
  parameter int SIGMA_BIT=4,
  parameter int BITS=14
) (
  input wire logic clk,
  input wire logic rst,
  alpaca_data_pkt_axis.MST m_axis
);

  typedef m_axis.data_t axis_t;

  localparam int samp_per_clk = m_axis.samp_per_clk;
  localparam int width = $bits(axis_t);

  // MSB align the to the AXI width to model RFDC
  localparam int AXI_MSB_ALIGN = width-BITS;

  localparam int MEAN = 0;
  localparam int SIGMA = 2**SIGMA_BIT;

  int n [samp_per_clk-1:0];
  axis_t noise [samp_per_clk-1:0];

  // needed to use an intial block to seed the process also, $dist_normal is an inout port and
  // so it returns the next value used (see LRM 1800-2017 for more information).
  int s;
  initial begin
    process proc;
    proc = process::self();
    proc.srandom(SEED);
    s = $urandom;
    $display("seed=%d, sigma bit=%d", SEED, SIGMA_BIT);
  end

  genvar ii;
  generate
  for (ii=0; ii<samp_per_clk; ii++) begin
    always_ff @(posedge clk)
      n[ii] <= $dist_normal(s, MEAN, SIGMA);
  end

  for (ii=0; ii<samp_per_clk; ii++) begin
    always_comb begin
      noise[ii] = n[ii];
      noise[ii] = noise[ii] << AXI_MSB_ALIGN;
      m_axis.tdata[ii] = noise[ii];
    end
  end
  endgenerate

  assign m_axis.tvalid = ~rst;

endmodule : awgn

/**************************************************
  TOP
  awgn -> capture
***************************************************/
module awgn_top #(
  parameter int SEED=123456789,
  parameter int SIGMA_BIT=1,
  parameter int BITS=14,
  parameter int SAMP_PER_CLK=2,
  parameter int SAMPLES=128
) (
  input wire logic clk,
  input wire logic rst,
  output logic vip_full
);

  localparam MEM_DEPTH = SAMPLES/SAMP_PER_CLK;
  alpaca_data_pkt_axis #(
    .dtype(sample_t),
    .SAMP_PER_CLK(SAMP_PER_CLK),
    .TUSER(1)
  ) m_axis();

  awgn #(.SEED(SEED), .SIGMA_BIT(SIGMA_BIT), .BITS(BITS)) awgn_inst (.*);

  parallel_axis_vip #(.DEPTH(MEM_DEPTH)) vip_inst (.*, .s_axis(m_axis), .full(vip_full));

endmodule : awgn_top

// using alpaca data axis interface
module re_to_cx_axis (
  alpaca_data_pkt_axis.SLV s_axis_re,
  alpaca_data_pkt_axis.SLV s_axis_im,

  alpaca_data_pkt_axis.MST m_axis_cx
);

localparam samp_per_clk = s_axis_re.samp_per_clk;

genvar ii;
generate
  for (ii=0; ii<samp_per_clk; ii++) begin : route_to_cx
    assign m_axis_cx.tdata[ii].im = s_axis_im.tdata[ii];
    assign m_axis_cx.tdata[ii].re = s_axis_re.tdata[ii];
  end
endgenerate

// slv passthrough on real, imag not used, synthesis should complain about s_axis_im not connected
assign m_axis_cx.tvalid = s_axis_re.tvalid;
assign m_axis_cx.tlast  = s_axis_re.tlast;

assign s_axis_re.tready = m_axis_cx.tready;
assign s_axis_im.tready = m_axis_cx.tready;

endmodule : re_to_cx_axis

/**************************************************
  TOP
  awgn -> capture
***************************************************/
module cx_awgn_top #(
  parameter int SEED_RE=12345,
  parameter int SEED_IM=67890,
  parameter int SIGMA_BIT=1,
  parameter int BITS=14,
  parameter int SAMP_PER_CLK=2,
  parameter int SAMPLES=128
) (
  input wire logic clk,
  input wire logic rst,
  output logic vip_full
);

  localparam MEM_DEPTH = SAMPLES/SAMP_PER_CLK;
  alpaca_data_pkt_axis #(
    .dtype(sample_t),
    .SAMP_PER_CLK(SAMP_PER_CLK),
    .TUSER(1)
  ) awgn_axis[SAMP_PER_CLK]();

  alpaca_data_pkt_axis #(
    .dtype(cx_t),
    .SAMP_PER_CLK(SAMP_PER_CLK),
    .TUSER(1)
  ) m_axis();

  awgn #(.SEED(SEED_RE), .SIGMA_BIT(SIGMA_BIT), .BITS(BITS)) awgn_inst_re (.*, .m_axis(awgn_axis[0]));
  awgn #(.SEED(SEED_IM), .SIGMA_BIT(SIGMA_BIT), .BITS(BITS)) awgn_inst_im (.*, .m_axis(awgn_axis[1]));

  re_to_cx_axis re_to_cx_axis_inst (
    .s_axis_re(awgn_axis[0]),
    .s_axis_im(awgn_axis[1]),
    .m_axis_cx(m_axis)
  );

  parallel_axis_vip #(.DEPTH(MEM_DEPTH)) vip_inst (.*, .s_axis(m_axis), .full(vip_full));

endmodule : cx_awgn_top

/**************************************************
  AWGN capture test bench
***************************************************/
import alpaca_constants_pkg::*;

parameter int SIGMA_BIT = 3;
parameter int AWGN_BITS = 16;
parameter int SAMPLES = 2048;

module awgn_tb();

  logic clk, rst, vip_full;

  clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);
  //awgn_top #(
  cx_awgn_top #(
    .SEED_RE(12340),
    .SEED_IM(67895),
    .SIGMA_BIT(SIGMA_BIT),
    .BITS(AWGN_BITS),
    .SAMP_PER_CLK(SAMP_PER_CLK),
    .SAMPLES(SAMPLES)
  ) DUT(.*);

  task wait_cycles(input int cycle=1);
    repeat (cycle)
      @(posedge clk);
  endtask

  // main block
  initial begin
    rst <= 1;
    @(posedge clk);
    @(negedge clk); rst = 0;

    while (~vip_full)
      wait_cycles();

    $writememb("awgn_capture_bin.txt", DUT.vip_inst.ram);

    $finish;
  end

endmodule : awgn_tb


