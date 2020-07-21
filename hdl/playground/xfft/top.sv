`timescale 1ns/1ps
`default_nettype none

/*
  Capture AXIS Samples from upstream until RAM is full.

  Cannot accept more samples until reset

  // Notes/ideas
  TLAST not implemented anwhere... do we work of tlast or just count samples?
  what does the snapshot ip do? TODO
*/
module axis_fft_vip #(
  parameter int WIDTH=32,
  parameter int DEPTH=32
) (
  input wire logic clk,
  input wire logic rst,
  axis.SLV s_axis,
  output logic full
);

logic [$clog2(DEPTH)-1:0] wAddr;
logic signed [WIDTH-1:0] ram [DEPTH];
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

assign s_axis.tready = ~full;

endmodule

/*
  FFT simulation top module
*/
module top #(
  parameter int DATA_WID=16,
  parameter int CONF_WID=16,
  parameter int SAMP = 32,
  parameter real PERIOD = 10
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  //axis.MST m_axis_data,
  axis.MST m_axis_status,
  output logic [7:0] m_axis_data_tuser,
  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt,
  output logic vip_full
);


axis #(.WIDTH(2*DATA_WID)) m_axis_data();
logic m_axis_data_tlast;

axis #(.WIDTH(2*DATA_WID)) s_axis_data(); // complex valued [16-bit im, 16-bit re]
logic s_axis_data_tlast;
assign s_axis_data_tlast = 1'b0;

axis #(.WIDTH(CONF_WID)) s_axis_config();
assign s_axis_config.tdata = 1'b0;
assign s_axis_config.tvalid = 1'b0;

adc_model #(
  .PERIOD(PERIOD),
  .TWID(DATA_WID),
  .DTYPE("CX")
) adc_inst (
  .clk(clk),
  .rst(rst),
  .en(en), // TODO: is it time to remove, I think it was temporarily added to test FFT functionality 
  .m_axis(s_axis_data)
);

logic aresetn;
assign aresetn = ~rst;

xfft_0 fft_inst (
                                                          // TODO: remove widths as some are
                                                          // residual from other templates

  .aclk(clk),                                            // input wire aclk
  .aresetn(aresetn),                                      // input wire aresetn

  .s_axis_config_tdata(s_axis_config.tdata),              // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(s_axis_config.tvalid),            // input wire s_axis_config_tvalid
  .s_axis_config_tready(s_axis_config.tready),            // output wire s_axis_config_tready

  .s_axis_data_tdata(s_axis_data.tdata),                  // input wire [31 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_axis_data.tvalid),                // input wire s_axis_data_tvalid
  .s_axis_data_tready(s_axis_data.tready),                // output wire s_axis_data_tready
  .s_axis_data_tlast(s_axis_data_tlast),                  // input wire s_axis_data_tlast

  .m_axis_data_tdata(m_axis_data.tdata),                  // output wire [31 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_axis_data.tvalid),                // output wire m_axis_data_tvalid
  .m_axis_data_tlast(m_axis_data_tlast),                  // output wire m_axis_data_tlast
  .m_axis_data_tuser(m_axis_data_tuser),                  // output wire [7 : 0] m_axis_data_tuser

  .m_axis_status_tdata(m_axis_status.tdata),              // output wire [7 : 0] m_axis_status_tdata
  .m_axis_status_tvalid(m_axis_status.tvalid),            // output wire m_axis_status_tvalid

  .event_frame_started(event_frame_started),              // output wire event_frame_started
  .event_tlast_unexpected(event_tlast_unexpected),        // output wire event_tlast_unexpected
  .event_tlast_missing(event_tlast_missing),              // output wire event_tlast_missing
  .event_fft_overflow(event_fft_overflow),                // output wire event_fft_overflow
  .event_data_in_channel_halt(event_data_in_channel_halt) // output wire event_data_in_channel_halt
);

axis_fft_vip #(
  .WIDTH(2*DATA_WID),
  .DEPTH(SAMP)
) vip_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_data),
  .full(vip_full)
);
  

endmodule
  
