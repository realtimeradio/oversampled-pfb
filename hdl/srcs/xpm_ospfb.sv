`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/*
  Top OSPFB Module
*/

module xpm_ospfb #(
  // ospfb parameters
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter fir_taps_t TAPS,
  parameter TWIDDLE_FILE="",
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
localparam width = $bits(data_pkt_t);
localparam samp_per_clk = s_axis.samp_per_clk;

alpaca_data_pkt_axis #(.TUSER(1)) s_axis_fifo();  // wires between sample delay and fifo
alpaca_data_pkt_axis #(.TUSER(1)) s_axis_ospfb(); // wires between dc fifo and ospfb

// As any real source will only provide causal data it seems most appropriate to add this
// module in the ospfb to perform the deelay necessary align the data correctly with the taps
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
  .TWIDDLE_FILE(TWIDDLE_FILE),
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
