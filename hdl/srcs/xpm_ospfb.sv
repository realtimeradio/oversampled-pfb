`timescale 1ns/1ps
`default_nettype none

//`ifndef FIR_TAPS
//  `define FIR_TAPS
//import alpaca_ospfb_ramp_64_8_coeff_pkg::TAPS;
//`endif

/*
  Top OSPFB Module
*/

module xpm_ospfb #(
  // data width parameter
  parameter int WIDTH=16,
  // ospfb parameters
  parameter int COEFF_WID=16,
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter logic signed [COEFF_WID-1:0] TAPS [PTAPS*FFT_LEN],
  // pe delay buffer memory architectures
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  // fft axis config parameters
  parameter int FFT_CONF_WID=8,
  parameter int FFT_USER_WID=8,
  // dc fifo
  parameter int DC_FIFO_DEPTH=32 // M/2 but I really think it only has to be M-D
) (
  input wire logic s_axis_aclk,  // adc clock
  input wire logic m_axis_aclk,  // dsp clock
  input wire logic rst, // TODO: consider calling it s_axis_rst for association with slv domain?
  input wire logic en,  // TODO: seemed to now only be used to control the modtimer counter
                        // shouldn't be too hard to remove now
  // slave interface
  axis.SLV s_axis,
  input wire logic s_axis_tlast,

  // master interface
  axis.MST m_axis_data,
  output logic m_axis_data_tlast,
  output logic [FFT_USER_WID-1:0] m_axis_data_tuser,

  // fft status singals
  axis.MST m_axis_fft_status,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt
);

// wire between dc fifo and ospfb
axis #(.WIDTH(2*WIDTH)) s_axis_ospfb();
logic s_axis_ospfb_tlast;

// pipelined/streaming in real-time mode has no ready
assign m_axis_fft_status.tready = 1'b0;

xpm_fifo_axis #(
  .CLOCKING_MODE("independent_clock"),
  .FIFO_DEPTH(DC_FIFO_DEPTH),
  .FIFO_MEMORY_TYPE("auto"),
  .RELATED_CLOCKS(1),
  .SIM_ASSERT_CHK(1),
  .TDATA_WIDTH(2*WIDTH)
) xpm_fifo_axis_inst (
  // TODO: hopefully ports are removed in synthesis if not connected or driven
  .almost_empty_axis(),
  .almost_full_axis(),

  .dbiterr_axis(),

  .m_axis_tdata(s_axis_ospfb.tdata),
  .m_axis_tdest(),
  .m_axis_tid(),
  .m_axis_tkeep(),
  .m_axis_tlast(s_axis_ospfb_tlast),
  .m_axis_tstrb(),
  .m_axis_tuser(),
  .m_axis_tvalid(s_axis_ospfb.tvalid),

  .prog_empty_axis(),
  .prog_full_axis(),

  .rd_data_count_axis(),

  .s_axis_tready(s_axis.tready),

  .sbiterr_axis(),

  .wr_data_count_axis(),

  .injectdbiterr_axis(1'b0),
  .injectsbiterr_axis(1'b0),

  .m_aclk(m_axis_aclk),
  .m_axis_tready(s_axis_ospfb.tready),

  .s_aclk(s_axis_aclk),
  .s_aresetn(~rst),

  .s_axis_tdata(s_axis.tdata),
  .s_axis_tdest('0),
  .s_axis_tid('0),
  .s_axis_tkeep('0),
  .s_axis_tlast(s_axis_tlast),
  .s_axis_tstrb('0),
  .s_axis_tuser('0),
  .s_axis_tvalid(s_axis.tvalid)
);

xpm_ospfb_datapath #(
  .WIDTH(WIDTH), // not 2*WIDTH because internal the OSPFB does that
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .LOOPBUF_MEM_TYPE(LOOPBUF_MEM_TYPE),
  .DATABUF_MEM_TYPE(DATABUF_MEM_TYPE),
  .SUMBUF_MEM_TYPE(SUMBUF_MEM_TYPE),
  .FFT_CONF_WID(FFT_CONF_WID),
  .FFT_USER_WID(FFT_USER_WID)
) datapath_inst (
  .clk(m_axis_aclk),
  .rst(rst),
  .en(en),
  .s_axis(s_axis_ospfb),
  .m_axis_fft_status(m_axis_fft_status),
  .m_axis_data(m_axis_data),
  .m_axis_data_tlast(m_axis_data_tlast),
  .m_axis_data_tuser(m_axis_data_tuser),
  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt)
);
endmodule
