`timescale 1ns/1ps
`default_nettype none

//`ifndef CONSTANTS
//  `define CONSTANTS
//  import alpaca_ospfb_constants_pkg::WIDTH;
//  import alpaca_ospfb_constants_pkg::COEFF_WID;
//  import alpaca_ospfb_constants_pkg::FFT_LEN;
//  import alpaca_ospfb_constants_pkg::DEC_FAC;
//  import alpaca_ospfb_constants_pkg::PTAPS;
//  import alpaca_ospfb_constants_pkg::DC_FIFO_DEPTH;
//  import alpaca_ospfb_constants_pkg::FFT_CONF_WID;
//  import alpaca_ospfb_constants_pkg::FFT_STAT_WID;
//  import alpaca_ospfb_constants_pkg::FFT_USER_WID;
//`endif

//`ifndef FIR_TAPS
//  `define FIR_TAPS
import alpaca_ospfb_ones_2048_8_coeff_pkg::TAPS;
//`endif

module synth_xpm_ospfb #(
  // data width parameter
  parameter int WIDTH=16,
  // ospfb parameters
  parameter int COEFF_WID=16,
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter int FFT_CONF_WID=8,
  parameter int FFT_STAT_WID=8,
  parameter int FFT_USER_WID=8,
  // dc fifo
  parameter int DC_FIFO_DEPTH=32 // M/2 but I really think it only has to be M-D
) (
  input wire logic s_axis_aclk,  // adc clock
  input wire logic m_axis_aclk,  // dsp clock
  input wire logic rst,
  input wire logic en,

  // slave interface
  input wire logic signed [2*WIDTH-1:0] s_axis_tdata,
  input wire logic s_axis_tvalid,
  input wire logic s_axis_tlast,
  output logic s_axis_tready,

  // master interface 
  output logic signed [2*WIDTH-1:0] m_axis_tdata,
  output logic [FFT_USER_WID-1:0] m_axis_tuser,
  output logic m_axis_tvalid,
  output logic m_axis_tlast,
  input wire logic m_axis_tready,

  // fft status singals
  output logic [FFT_STAT_WID-1:0] m_axis_fft_status_tdata,
  output logic m_axis_fft_status_tvalid,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt
);

axis #(.WIDTH(2*WIDTH)) m_axis_data(), s_axis_ospfb();
axis #(.WIDTH(FFT_STAT_WID)) m_axis_fft_status();
logic s_axis_ospfb_tlast;

// wire interface out of ospfb to top-level output m_axis port
assign m_axis_tdata = m_axis_data.tdata;
assign m_axis_tvalid = m_axis_data.tvalid;
assign m_axis_data.tready = m_axis_tready;

assign m_axis_fft_status_tdata = m_axis_fft_status.tdata;
assign m_axis_fft_status_tvalid = m_axis_fft_status.tvalid;
assign m_axis_fft_status.tready = 1'b0;// pipelined/streaming in real-time mode has no ready

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

  .s_axis_tready(s_axis_tready),

  .sbiterr_axis(),

  .wr_data_count_axis(),

  .injectdbiterr_axis(1'b0),
  .injectsbiterr_axis(1'b0),

  .m_aclk(m_axis_aclk),
  .m_axis_tready(s_axis_ospfb.tready),

  .s_aclk(s_axis_aclk),
  .s_aresetn(~rst),

  .s_axis_tdata(s_axis_tdata),
  .s_axis_tdest('0),
  .s_axis_tid('0),
  .s_axis_tkeep('0),
  .s_axis_tlast(s_axis_tlast),
  .s_axis_tstrb('0),
  .s_axis_tuser('0),
  .s_axis_tvalid(s_axis_tvalid)
);

xpm_ospfb #(
  .WIDTH(WIDTH), // not 2*WIDTH because internal the OSPFB does that
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .LOOPBUF_MEM_TYPE("auto"),
  .DATABUF_MEM_TYPE("auto"),
  .SUMBUF_MEM_TYPE("auto"),
  .CONF_WID(FFT_CONF_WID),
  .TUSER_WID(FFT_USER_WID)
) ospfb_inst (
  .clk(m_axis_aclk),
  .rst(rst),
  .en(en),
  .s_axis(s_axis_ospfb),
  .m_axis_fft_status(m_axis_fft_status),
  .m_axis_data(m_axis_data),
  .m_axis_data_tlast(m_axis_tlast),
  .m_axis_data_tuser(m_axis_tuser),
  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt)
);
endmodule
