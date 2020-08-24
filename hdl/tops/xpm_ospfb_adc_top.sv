`timescale 1ns/1ps
`default_nettype none

module xpm_ospfb_adc_top #(
  // ADC parameters
  parameter real SRC_PERIOD=10,
  parameter int ADC_BITS=12,
  // OSPFB parameters
  parameter int WIDTH=16,
  parameter int FFT_LEN=64,
  parameter int SAMP=FFT_LEN,
  parameter int COEFF_WID=16,
  parameter int DEC_FAC=48,
  parameter int SRT_PHA=DEC_FAC-1,
  parameter int PTAPS=3,
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
adc_model #(
  .PERIOD(SRC_PERIOD),
  .TWID(WIDTH),
  .DTYPE("CX"),
  .BITS(ADC_BITS)
) adc_inst (
  .clk(clka),
  .rst(rst),
  // TODO: is it time to remove, I think it was temporarily added to test FFT functionality 
  .en(en),
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
   // for the advanced features refer to documentation
   // each digit is a hex value, with 4 hex values there are 16 bits to toggle but the
   // documentation only explains what some of the bits from [0-11] but by default has the 13th
   // bit set. Comparing the AXIS FIFO with the standard FIFO that this is essentially a wrapper
   // explains what that bit does and makes sense why it is set here but not explained. However,
   // even if you force that bit 0 it is ignored and and reset back to 1 in simulation and
   // synthesis.
   .USE_ADV_FEATURES("1E0E"),
   .WR_DATA_COUNT_WIDTH(DATA_COUNT_WIDTH)
) xpm_fifo_axis_inst (
   .almost_empty_axis(almost_empty), // 1-bit output: Almost Empty : When asserted, this signal
                                     // indicates that only one more read can be
                                     // performed before the FIFO goes to empty.

   .almost_full_axis(almost_full),   // 1-bit output: Almost Full: When asserted, this signal
                                     // indicates that only one more write can be
                                     // performed before the FIFO is full.

   .m_axis_tdata(s_axis_ospfb.tdata),
   .m_axis_tlast(s_axis_ospfb_tlast),
   .m_axis_tvalid(s_axis_ospfb.tvalid),

   .prog_empty_axis(prog_empty),   // 1-bit output: Programmable Empty- This signal is asserted
                                   // when the number of words in the FIFO is less than
                                   // or equal to the programmable empty threshold
                                   // value. It is de-asserted when the number of words
                                   // in the FIFO exceeds the programmable empty
                                   // threshold value.

   .prog_full_axis(prog_full),     // 1-bit output: Programmable Full: This signal is asserted when
                                   // the number of words in the FIFO is greater than
                                   // or equal to the programmable full threshold
                                   // value. It is de-asserted when the number of words
                                   // in the FIFO is less than the programmable full
                                   // threshold value.

   .rd_data_count_axis(rd_count),  // RD_DATA_COUNT_WIDTH-bit output: Read Data Count- This bus
                                   // indicates the number of words available for reading in the FIFO.

   .s_axis_tready(s_axis.tready),

   .wr_data_count_axis(wr_count),  // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus
                                   // indicates the number of words written into the
                                   // FIFO.

   .m_aclk(clkb),

   .m_axis_tready(s_axis_ospfb.tready),

   .s_aclk(clka),

   .s_aresetn(~rst),

   .s_axis_tdata(s_axis.tdata),
   .s_axis_tlast(s_axis_tlast),
   .s_axis_tvalid(s_axis.tvalid)

);

xpm_ospfb #(
  .WIDTH(WIDTH),
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
