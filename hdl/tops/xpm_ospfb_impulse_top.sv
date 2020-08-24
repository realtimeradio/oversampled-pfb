`timescale 1ns/1ps
`default_nettype none

module xpm_ospfb_impulse_top #(
  parameter int WIDTH=16,
  parameter int FFT_LEN=64,
  parameter int SAMP=FFT_LEN,
  parameter int COEFF_WID=16,
  parameter int DEC_FAC=48,
  parameter int SRT_PHA=DEC_FAC-1,
  parameter int PTAPS=3,
  parameter int IMPULSE_PHASE=DEC_FAC+1,
  parameter int PULSE_VAL = 1,
  parameter int SRLEN=4,
  parameter logic signed [COEFF_WID-1:0] TAPS [PTAPS*FFT_LEN],
  parameter int CONF_WID=8,
  // fifo parameters
  parameter int FIFO_DEPTH=(FFT_LEN-DEC_FAC),
  parameter int PROG_EMPTY_THRESH=FIFO_DEPTH/2,
  parameter int PROG_FULL_THRESH=FIFO_DEPTH/2,
  parameter int DATA_COUNT_WIDTH=$clog2(FIFO_DEPTH)
) (
  input wire logic clka,
  input wire logic clkb,
  input wire logic rst,
  input wire logic en,

  // fft singals
  axis.MST m_axis_fft_status,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt,
  // fifo signals
  output logic almost_empty,
  output logic almost_full,
  output logic prog_empty,
  output logic prog_full,
  output logic [DATA_COUNT_WIDTH-1:0] rd_count,
  output logic [DATA_COUNT_WIDTH-1:0] wr_count,

  // vip signal
  output logic vip_full
);

// complex valued [16-bit im, 16-bit re]
axis #(.WIDTH(2*WIDTH)) s_axis(), s_axis_ospfb();
logic s_axis_tlast, s_axis_ospfb_tlast;

axis #(.WIDTH(2*WIDTH)) m_axis_data();
logic m_axis_data_tlast;
logic [7:0] m_axis_data_tuser;

// data source for simulation
impulse_generator #(
    .WIDTH(2*WIDTH), // will get the {im, re} structure with the pulse in the re location
    .IMPULSE_PHASE(IMPULSE_PHASE),
    .PULSE_VAL(PULSE_VAL),
    .MAX_CNT(FFT_LEN)
  ) impulse_gen_inst (
    .clk(clka),
    .rst(rst),
    .m_axis(s_axis)
  );

xpm_fifo_axis #(
   .CDC_SYNC_STAGES(2),
   .CLOCKING_MODE("independent_clock"),
   .ECC_MODE("no_ecc"),
   .FIFO_DEPTH(FIFO_DEPTH),
   .FIFO_MEMORY_TYPE("auto"),
   .PACKET_FIFO("false"),
   .PROG_EMPTY_THRESH(PROG_EMPTY_THRESH),
   .PROG_FULL_THRESH(PROG_FULL_THRESH),
   .RD_DATA_COUNT_WIDTH(DATA_COUNT_WIDTH),
   .RELATED_CLOCKS(1),
   .SIM_ASSERT_CHK(1),
   .TDATA_WIDTH(2*WIDTH),
   .TDEST_WIDTH(1),
   .TID_WIDTH(1),
   .TUSER_WIDTH(1),
   .USE_ADV_FEATURES("1E0E"),
   .WR_DATA_COUNT_WIDTH(DATA_COUNT_WIDTH)
) xpm_fifo_axis_inst (
  // TODO: hopefully ports are removed in synthesis if not connected or driven
  .almost_empty_axis(almost_empty),
  .almost_full_axis(almost_full),

  .dbiterr_axis(),

  .m_axis_tdata(s_axis_ospfb.tdata),
  .m_axis_tdest(),
  .m_axis_tid(),
  .m_axis_tkeep(),
  .m_axis_tlast(s_axis_ospfb_tlast),
  .m_axis_tstrb(),
  .m_axis_tuser(),
  .m_axis_tvalid(s_axis_ospfb.tvalid),

  .prog_empty_axis(prog_empty),
  .prog_full_axis(prog_full),

  .rd_data_count_axis(rd_count),

  .s_axis_tready(s_axis.tready),

  .sbiterr_axis(),

  .wr_data_count_axis(wr_count),
  
  .injectdbiterr_axis(1'b0),
  .injectsbiterr_axis(1'b0),

  .m_aclk(clkb),
  .m_axis_tready(s_axis_ospfb.tready),

  .s_aclk(clka),
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

xpm_ospfb #(
  .WIDTH(WIDTH), // not 2*WIDTH because internal the OSPFB does that
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN),
  .TAPS(TAPS),
  .CONF_WID(CONF_WID)
) ospfb_inst (
  .clk(clkb),
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

axis_vip #(
  .WIDTH(2*WIDTH),
  .DEPTH(SAMP)
) vip_inst (
  .clk(clkb),
  .rst(rst),
  .s_axis(m_axis_data),
  .full(vip_full)
);


endmodule
