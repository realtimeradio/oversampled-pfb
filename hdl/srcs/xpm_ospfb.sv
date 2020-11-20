`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_dtypes_pkg::*;

/**************************************************
  Top Module
***************************************************/

module xpm_ospfb_top #(
) (
  input wire logic s_axis_aclk,
  input wire logic m_axis_aclk,
  input wire logic rst,
  input wire logic en,

  input wire cx_pkt_t s_axis_tdata,
  input wire logic s_axis_tvalid,
  input wire logic s_axis_tlast,
  output logic s_axis_tready,

  output cx_pkt_t m_axis_tdata,
  output logic m_axis_tvalid,
  output logic m_axis_tlast,
  input wire logic m_axis_tready,
  output logic [15:0] m_axis_tuser,

  // fft status singals
  alpaca_xfft_status_axis.MST m_axis_fft_status_x2,
  alpaca_xfft_status_axis.MST m_axis_fft_status_x1,
  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt
);

  alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(1)) s_axis();
  alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(2*8)) m_axis_Xk();

  assign s_axis.tdata = s_axis_tdata;
  assign s_axis.tvalid = s_axis_tvalid;
  assign s_axis.tlast = s_axis_tlast;
  assign s_axis_tready = s_axis.tready;
  assign s_axis.tuser = 1'b0;

  assign m_axis_tdata = m_axis_Xk.tdata;
  assign m_axis_tvalid = m_axis_Xk.tvalid;
  assign m_axis_tlast = m_axis_Xk.tlast;
  assign m_axis_tuser = m_axis_Xk.tuser;
  assign m_axis_Xk.tready = m_axis_tready;

  xpm_ospfb #(
    .FFT_LEN(FFT_LEN),
    .DEC_FAC(DEC_FAC),
    .PTAPS(PTAPS),
    .TAPS(alpaca_ospfb_hann_2048_8_coeff_pkg::TAPS),
    .WK(alpaca_ospfb_twiddle_n2048_b23_pkg::WK),
    .DC_FIFO_DEPTH(DC_FIFO_DEPTH)
  ) ospfb_inst (
    .s_axis_aclk(s_axis_aclk),
    .m_axis_aclk(m_axis_aclk),
    .rst(rst),
    .en(en),

    .s_axis(s_axis),
    .m_axis_data(m_axis_Xk),

    .m_axis_fft_status_x2(m_axis_fft_status_x2),
    .m_axis_fft_status_x1(m_axis_fft_status_x1),
    .event_frame_started(event_frame_started),
    .event_tlast_unexpected(event_tlast_unexpected),
    .event_tlast_missing(event_tlast_missing),
    .event_fft_overflow(event_fft_overflow),
    .event_data_in_channel_halt(event_data_in_channel_halt)
);

endmodule : xpm_ospfb_top

/***********************************************
  OSPFB
************************************************/

module xpm_ospfb #(
  // ospfb parameters
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter fir_taps_t TAPS,
  parameter twiddle_factor_t WK,
  // pe delay buffer memory architectures
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  // dc fifo
  parameter int DC_FIFO_DEPTH=32 // M/2 but I really think it only has to be M-D
) (
  input wire logic s_axis_aclk,  // adc clock
  input wire logic m_axis_aclk,  // dsp clock
  input wire logic rst, // TODO: consider calling it s_axis_rst for association with slv domain?
                        //       in really though I need to properly handle the reset...
  input wire logic en,  // TODO: seemed to now only be used to control the modtimer counter
                        // shouldn't be too hard to remove now

  alpaca_data_pkt_axis.SLV s_axis,
  alpaca_data_pkt_axis.MST m_axis_data,

  // fft status singals
  alpaca_xfft_status_axis.MST m_axis_fft_status_x2,
  alpaca_xfft_status_axis.MST m_axis_fft_status_x1,
  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt
);

typedef s_axis.data_pkt_t data_pkt_t;
localparam width = s_axis.width;
localparam samp_per_clk = s_axis.samp_per_clk;

alpaca_data_pkt_axis #(.TUSER(1)) s_axis_fifo();  // wires between sample delay and fifo
alpaca_data_pkt_axis #(.TUSER(1)) s_axis_ospfb(); // wires between dc fifo and ospfb

// As any real source will only provide causal data it seems this should be part
// of the ospfb as to add the delay's necessary to align the data with the taps
sample_delay sample_delay_inst (
  .clk(s_axis_aclk),
  .s_axis(s_axis),
  .m_axis(s_axis_fifo)
);

xpm_fifo_axis #(
  .CLOCKING_MODE("independent_clock"),
  .FIFO_DEPTH(DC_FIFO_DEPTH),
  .FIFO_MEMORY_TYPE("auto"),
  .RELATED_CLOCKS(1),
  .SIM_ASSERT_CHK(1),
  .TDATA_WIDTH(width)
) xpm_fifo_axis_inst (
  // TODO: hopefully ports are removed in synthesis if not connected or driven
  .almost_empty_axis(),
  .almost_full_axis(),

  .dbiterr_axis(),

  .m_axis_tdata(s_axis_ospfb.tdata),
  .m_axis_tdest(),
  .m_axis_tid(),
  .m_axis_tkeep(),
  .m_axis_tlast(s_axis_ospfb.tlast),
  .m_axis_tstrb(),
  .m_axis_tuser(),
  .m_axis_tvalid(s_axis_ospfb.tvalid),

  .prog_empty_axis(),
  .prog_full_axis(),

  .rd_data_count_axis(),

  .s_axis_tready(s_axis_fifo.tready),

  .sbiterr_axis(),

  .wr_data_count_axis(),

  .injectdbiterr_axis(1'b0),
  .injectsbiterr_axis(1'b0),

  .m_aclk(m_axis_aclk),
  .m_axis_tready(s_axis_ospfb.tready),

  .s_aclk(s_axis_aclk),
  .s_aresetn(~rst),

  .s_axis_tdata(s_axis_fifo.tdata),
  .s_axis_tdest('0),
  .s_axis_tid('0),
  .s_axis_tkeep('0),
  .s_axis_tlast(s_axis_fifo.tlast),
  .s_axis_tstrb('0),
  .s_axis_tuser('0),
  .s_axis_tvalid(s_axis_fifo.tvalid)
);

xpm_ospfb_datapath #(
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA((DEC_FAC/samp_per_clk)-1),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .WK(WK),
  .LOOPBUF_MEM_TYPE(LOOPBUF_MEM_TYPE),
  .DATABUF_MEM_TYPE(DATABUF_MEM_TYPE),
  .SUMBUF_MEM_TYPE(SUMBUF_MEM_TYPE)
) datapath_inst (
  .clk(m_axis_aclk),
  .rst(rst),
  .en(en),
  // data signals
  .s_axis(s_axis_ospfb),
  .m_axis_data(m_axis_data),
  //status signals
  .m_axis_fft_status_x2(m_axis_fft_status_x2),
  .m_axis_fft_status_x1(m_axis_fft_status_x1),
  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt)
);

endmodule : xpm_ospfb
