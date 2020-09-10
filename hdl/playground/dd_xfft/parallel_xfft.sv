`timescale 1ns/1ps
`default_nettype none

/*******************************
  parameters and interface
********************************/
package alpaca_dtypes_pkg;

parameter int WIDTH = 16;
parameter int PHA_WID = 23;
parameter int SAMP_PER_CLK = 2;

typedef logic signed [WIDTH-1:0] sample_t;

typedef struct packed {
  logic signed [WIDTH-1:0] im;
  logic signed [WIDTH-1:0] re;
} cx_t;

typedef struct packed {
  logic signed [PHA_WID-1:0] im;
  logic signed [PHA_WID-1:0] re;
} cx_wk_t;

typedef cx_t [SAMP_PER_CLK-1:0] cx_pkt_t;

typedef sample_t [SAMP_PER_CLK-1:0] fir_t;

endpackage

import alpaca_dtypes_pkg::*;

interface alpaca_axis #(parameter type dtype, parameter TUSER) ();

  dtype tdata;
  logic tvalid, tready;
  logic tlast;
  logic [TUSER-1:0] tuser;

  modport MST (input tready, output tdata, tvalid, tlast, tuser);
  modport SLV (input tdata, tvalid, tlast, tuser, output tready);

endinterface

/****************************
    Data source generator 
*****************************/
module impulse_generator6 #(
  parameter int FFT_LEN=16,
  parameter int SAMP_PER_CLK=2,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_axis.MST m_axis
);

localparam MEM_DEPTH = FFT_LEN/SAMP_PER_CLK;

logic [$clog2(MEM_DEPTH)-1:0] rAddr;

cx_pkt_t ram [MEM_DEPTH];

initial begin
  for (int i=0; i<MEM_DEPTH; i++) begin
    cx_pkt_t pkt;
    for (int j=0; j<SAMP_PER_CLK; j++) begin
      cx_t tmp;
      // load counter in either real, imaginary or both
      tmp.re = i*SAMP_PER_CLK+ j;
      //tmp.im = i*SAMP_PER_CLK+ j;
      // load impulse value
      tmp.re = (i*SAMP_PER_CLK+j == IMPULSE_PHA) ? IMPULSE_VAL : '0;
      tmp.im = '0;

      pkt[j] = tmp;
    end
  ram[i] = pkt;
  end
end

always_ff @(posedge clk)
  if (rst)
    rAddr <= '0;
  else if (m_axis.tready)
    rAddr <= rAddr + 1; //+ samp_per_clk;
  else
    rAddr <= rAddr;

assign m_axis.tdata = { >> {ram[rAddr]}};
assign m_axis.tvalid = (~rst & m_axis.tready);
assign m_axis.tlast = (rAddr == MEM_DEPTH-1) ? 1'b1 : 1'b0;
assign m_axis.tuser = '0;

endmodule : impulse_generator6

////////////////////////////////////////

// purley combinational
module seperate_stream #(

) (
  alpaca_axis.SLV s_axis,

  alpaca_axis.MST m_axis_x2, // hi, newest (odd sample, time idx)
  alpaca_axis.MST m_axis_x1  // lo, oldest (even sample, time idx)
);

  // just an AXIS passthrough, re-wire
  // TODO: Is this the right thing to do (particularly with the s_axis)?
  assign s_axis.tready = (m_axis_x2.tready & m_axis_x1.tready);

  assign m_axis_x2.tdata = s_axis.tdata[1];
  assign m_axis_x1.tdata = s_axis.tdata[0];

  assign m_axis_x2.tvalid = s_axis.tvalid;
  assign m_axis_x1.tvalid = s_axis.tvalid;

  assign m_axis_x2.tlast = s_axis.tlast;
  assign m_axis_x1.tlast = s_axis.tlast;

  assign m_axis_x2.tuser = s_axis.tuser;
  assign m_axis_x1.tuser = s_axis.tuser;

endmodule : seperate_stream


/**********************************
  system verilog xfft wrapper
***********************************/

module sv_xfft_0_wrapper (
  input wire logic clk,
  input wire logic rst,

  alpaca_axis.SLV s_axis_data,
  alpaca_axis.SLV s_axis_config,

  alpaca_axis.MST m_axis_data,
  alpaca_axis.MST m_axis_status,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt
);

// xilinx fft is reset low
logic aresetn;
assign aresetn = ~rst;

xfft_0 xfft_inst (
  .aclk(clk), 
  .aresetn(aresetn),
  // Confguration channel to set inverse transform and scaling schedule
  // (width dependent on configuration and selected optional features)
  .s_axis_config_tdata(s_axis_config.tdata),
  .s_axis_config_tvalid(s_axis_config.tvalid),
  .s_axis_config_tready(s_axis_config.tready),

  .s_axis_data_tdata(s_axis_data.tdata),
  .s_axis_data_tvalid(s_axis_data.tvalid),
  .s_axis_data_tready(s_axis_data.tready),
  .s_axis_data_tlast(s_axis_data.tlast),

  .m_axis_data_tdata(m_axis_data.tdata),
  .m_axis_data_tvalid(m_axis_data.tvalid),
  .m_axis_data_tlast(m_axis_data.tlast),
  .m_axis_data_tuser(m_axis_data.tuser),
  // Status channel for overflow information and optional Xk index
  // (width dependent on configuration and selected optional features)
  .m_axis_status_tdata(m_axis_status.tdata),
  .m_axis_status_tvalid(m_axis_status.tvalid),

  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt)
);

endmodule : sv_xfft_0_wrapper


/******************************************
  last stage twidle factor combination
******************************************/
//module alpaca_butterfly #(
//  parameter int FFT_LEN=16,
//  parameter int PHA_WID=23
//) (
//  input wire logic clk,
//  input wire logic rst,
//
//  alpaca_axis.SLV x1,
//  alpaca_axis.SLV x2,
//
//  alpaca_axis.MST Xk
//);
//
///*
//  TODO:
//    - Wk counter
//    - data width of Xlo, Xhi
//    - AXIS protocol
//    - these need to be complex multiplies
//*/
//
//cx_wk_t Wk [FFT_LEN/2];
//
//initial begin
//  $readmemh("", Wk);
//end
//
//// but need to be complex
////Xlo = X1 + Wk*X2
////Xhi = X1 - Wk*X2
//
//logic signed [] Xlo, Xhi;
//
//always_comb begin
//  Xlo = x1.tdata + Wk*x2.tdata;
//end
//
//always_comb begin
//  Xhi = x1.tdata - Wk*x2.tdata;
//end
//
//always_ff @(posedge clk)
//  if (rst)
//    Xk.tdata <= '0;
//  else
//    Xk.tdata <= {Xhi, Xlo};
//    
//
//endmodule : alpaca_butterfly

/*******************************************
  Simple parallel fft from Xilinx fft's
********************************************/
module parallel_xfft #(
  parameter int TUSER=8
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_axis.SLV s_axis,
  alpaca_axis.SLV s_axis_config_x2,
  alpaca_axis.SLV s_axis_config_x1,

  alpaca_axis.MST m_axis_fft_x2,
  alpaca_axis.MST m_axis_fft_x1,

  alpaca_axis.MST m_axis_fft_status_x2,
  alpaca_axis.MST m_axis_fft_status_x1,

  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt
);

alpaca_axis #(.dtype(cx_t), .TUSER(TUSER)) s_axis_fft_x2(), s_axis_fft_x1();

seperate_stream ss_inst (//no clk -- combinational circuit
  .s_axis(s_axis),
  .m_axis_x2(s_axis_fft_x2),
  .m_axis_x1(s_axis_fft_x1)
);

sv_xfft_0_wrapper xfft_2 (
  .clk(clk), 
  .rst(rst),
  // Confguration channel to set inverse transform and scaling schedule
  // (width dependent on configuration and selected optional features)
  .s_axis_config(s_axis_config_x2),
  .s_axis_data(s_axis_fft_x2),

  .m_axis_data(m_axis_fft_x2),
  // Status channel for overflow information and optional Xk index
  // (width dependent on configuration and selected optional features)
  .m_axis_status(m_axis_fft_status_x2),

  .event_frame_started(event_frame_started[1]),
  .event_tlast_unexpected(event_tlast_unexpected[1]),
  .event_tlast_missing(event_tlast_missing[1]),
  .event_fft_overflow(event_fft_overflow[1]),
  .event_data_in_channel_halt(event_data_in_channel_halt[1])
);

sv_xfft_0_wrapper xfft_1 (
  .clk(clk), 
  .rst(rst),
  // Confguration channel to set inverse transform and scaling schedule
  // (width dependent on configuration and selected optional features)
  .s_axis_config(s_axis_config_x1),
  .s_axis_data(s_axis_fft_x1),

  .m_axis_data(m_axis_fft_x1),
  // Status channel for overflow information and optional Xk index
  // (width dependent on configuration and selected optional features)
  .m_axis_status(m_axis_fft_status_x1),

  .event_frame_started(event_frame_started[0]),
  .event_tlast_unexpected(event_tlast_unexpected[0]),
  .event_tlast_missing(event_tlast_missing[0]),
  .event_fft_overflow(event_fft_overflow[0]),
  .event_data_in_channel_halt(event_data_in_channel_halt[0])
);

endmodule : parallel_xfft

/********************************************
  simple dtype parameterized capture
  - stores `DEPTH` number of `dtype` words
*********************************************/
module axis_vip #(
  parameter type dtype,
  parameter int DEPTH=1024
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_axis.SLV s_axis,
  output logic full
);

logic [$clog2(DEPTH)-1:0] wAddr;
dtype ram [DEPTH];
logic wen;

assign wen = (s_axis.tready & s_axis.tvalid);

always_ff @(posedge clk)
  if (rst)
    wAddr <= '0;
  else if (wen)
    wAddr <= wAddr + 1;
  else
    wAddr <= wAddr;

always_ff @(posedge clk)
  if (wen)
    ram[wAddr] <= s_axis.tdata;

// cannot accept any more writes until reset
// registered the full signal so that it will be asserted after DEPTH number of
// samples have been written, otherwise as soon as wAddr == DEPTH-1 full is asserted
// and we don't register the last value
always_ff @(posedge clk)
  if (rst)
    full <= 1'b0;
  else if (wAddr == DEPTH-1)
    full <= 1'b1;
  else
    full <= full;
//assign full = (wAddr == DEPTH-1) ? 1'b1 : 1'b0;

assign s_axis.tready = (~full & ~rst);

endmodule : axis_vip

module pt_top #(
  parameter int FFT_LEN=16,
  parameter int SAMP_PER_CLK=2,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1,
  parameter int TUSER=8,
  // capture parameters
  parameter int FRAMES = 2

) (
  input wire logic clk,
  input wire logic rst,

  output logic [1:0] full
);

alpaca_axis #(.dtype(cx_pkt_t), .TUSER(TUSER)) s_axis();
alpaca_axis #(.dtype(cx_t), .TUSER(TUSER)) m_axis_x1(), m_axis_x2();

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) impulse_gen_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

seperate_stream ss_inst (//no clk -- combinational circuit
  .s_axis(s_axis),
  .m_axis_x2(m_axis_x2),
  .m_axis_x1(m_axis_x1)
);

axis_vip #(
  .dtype(cx_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) x2_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_x2),
  .full(full[1])
);

axis_vip #(
  .dtype(cx_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) x1_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_x1),
  .full(full[0])
);

endmodule : pt_top

/******************************************************
  Top module: impulse -> parallel fft -> axis capture
*******************************************************/

module parallel_xfft_top #(
  parameter int FFT_LEN=16,
  parameter int SAMP_PER_CLK=2,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1,
  parameter int TUSER=8,
  // capture parameters
  parameter int FRAMES = 2
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_axis.SLV s_axis_fft_config_x2,
  alpaca_axis.SLV s_axis_fft_config_x1,

  alpaca_axis.MST m_axis_fft_status_x2,
  alpaca_axis.MST m_axis_fft_status_x1,

  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt,

  output logic [1:0] full
);

alpaca_axis #(.dtype(cx_pkt_t), .TUSER(TUSER)) s_axis();
alpaca_axis #(.dtype(cx_t), .TUSER(TUSER)) m_axis_fft_x1(), m_axis_fft_x2();

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) impulse_gen_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

parallel_xfft #(
  .TUSER(TUSER)
) p_xfft_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis),
  .s_axis_config_x2(s_axis_fft_config_x2),
  .s_axis_config_x1(s_axis_fft_config_x1),

  .m_axis_fft_x2(m_axis_fft_x2),
  .m_axis_fft_x1(m_axis_fft_x1),

  .m_axis_fft_status_x2(m_axis_fft_status_x2),
  .m_axis_fft_status_x1(m_axis_fft_status_x1),

  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt) 
);

axis_vip #(
  .dtype(cx_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) x2_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_fft_x2),
  .full(full[1])
);

axis_vip #(
  .dtype(cx_t),
  .DEPTH(FRAMES*(FFT_LEN/SAMP_PER_CLK))
) x1_vip (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_fft_x1),
  .full(full[0])
);

endmodule : parallel_xfft_top

/*************************
  TESTBENCH
*************************/
parameter int PERIOD = 10;

parameter int FFT_LEN = 32;
parameter int FFT_CONF_WID = 8;
parameter int FFT_STAT_WID = 8;
parameter int FRAMES = 2;

parameter int IMPULSE_PHA = 2;
parameter int IMPULSE_VAL = 256;

parameter int TUSER = 8;

module tb();

logic clk, rst;

alpaca_axis #(.dtype(cx_t), .TUSER(TUSER)) m_axis_fft_x1(), m_axis_fft_x2();
// xfft defaults to forward transform can't remember default scaling
alpaca_axis #(.dtype(logic [FFT_CONF_WID-1:0]), .TUSER(TUSER)) s_axis_fft_config_x1(), s_axis_fft_config_x2();
alpaca_axis #(.dtype(logic [FFT_STAT_WID-1:0]), .TUSER(TUSER)) m_axis_fft_status_x1(), m_axis_fft_status_x2();

logic [1:0] event_frame_started;
logic [1:0] event_tlast_unexpected;
logic [1:0] event_tlast_missing;
logic [1:0] event_fft_overflow;
logic [1:0] event_data_in_channel_halt;

logic [1:0] full;

clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

parallel_xfft_top #( // pt_top
  .FFT_LEN(FFT_LEN),
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL),
  .TUSER(TUSER),
  .FRAMES(FRAMES)
) DUT (.*);

task wait_cycles(int cycles=1);
  repeat (cycles)
    @(posedge clk);
endtask

initial begin

  int fp;

  $display("Source ram contents");
  for (int i=0; i<FFT_LEN/SAMP_PER_CLK; i++) begin
    $display("(ram: 0x%0p", DUT.impulse_gen_inst.ram[i]);
  end
  $display("");

  rst <= 1; m_axis_fft_x1.tready <= 0; m_axis_fft_x2.tready <=0; // ?? do I need to force these?
  wait_cycles(5); // xfft needs reset applied for at least 2.
  @(negedge clk); rst = 0;

  while (full != 2'b11) begin
   wait_cycles(1);
  end

  for (int i=0; i<FRAMES; i++) begin
    $display("Frame: %0d", i);
    for (int j=0; j<FFT_LEN/SAMP_PER_CLK; j++) begin
      $display("hi: (re: 0x%0X, im: 0x%0X), lo: (re: 0x%0X, im: 0x%0X)",
        DUT.x2_vip.ram[j].re, DUT.x2_vip.ram[j].im,
        DUT.x1_vip.ram[j].re, DUT.x1_vip.ram[j].im);
    end
    $display("");
  end

  // write formatted binary
  fp = $fopen("parallel_fft.bin", "wb");
  if (!fp) begin
    $display("could not create file...");
    $finish;
  end

  for (int i=0; i<FRAMES; i++) begin
    for (int j=0; j<FFT_LEN/SAMP_PER_CLK; j++) begin
      $fwrite(fp, "%u", DUT.x2_vip.ram[j]); // writes 4 bytes in native endian format
      $fwrite(fp, "%u", DUT.x1_vip.ram[j]);
    end
  end
  $fclose(fp);

  //wait_cycles(20);
  //@(negedge clk); m_axis_fft_0.tready = 1; m_axis_fft_1.tready = 1;
  //@(posedge clk);
  //for (int i=0; i<2*FFT_LEN; i++) begin
  //  $display("(m_axis_fft_1.tdata: 0x%0X, m_axis_fft_0.tdata: 0x%0X)",
  //                m_axis_fft_1.tdata, m_axis_fft_0.tdata); // could be %p or %X here as a packed type
  //  wait_cycles(1);
  //end

  $finish;
end

endmodule : tb




