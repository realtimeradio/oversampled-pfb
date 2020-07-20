`timescale 1ns/1ps
`default_nettype none

module top #(
  parameter WIDTH=16,
  parameter real PERIOD = 10
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  axis.MST m_axis_data,
  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_data_in_channel_halt
);

logic m_axis_data_tlast;
assign m_axis_data_tlast = 1'b0;

axis #(.WIDTH(2*WIDTH)) s_axis_data(); // complex valued [16-bit im, 16-bit re]

logic s_axis_data_tlast;
assign s_axis_data_tlast = 1'b0;

axis #(.WIDTH(8)) s_axis_config();
assign s_axis_config.tdata = 1'b0;
assign s_axis_config.tvalid = 1'b0;

adc_model #(
  .PERIOD(PERIOD),
  .TWID(WIDTH),
  .DTYPE("CX")
) adc_inst (
  .clk(clk),
  .rst(rst),
  .en(en),
  .m_axis(s_axis_data)
);

logic aresetn;
assign aresetn = ~rst;

xfft_0 fft_inst (
  .aclk(clk),                                             // input wire aclk
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

  .event_frame_started(event_frame_started),              // output wire event_frame_started
  .event_tlast_unexpected(event_tlast_unexpected),        // output wire event_tlast_unexpected
  .event_tlast_missing(event_tlast_missing),              // output wire event_tlast_missing
  .event_data_in_channel_halt(event_data_in_channel_halt) // output wire event_data_in_channel_halt
);


endmodule
  
