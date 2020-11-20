`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_dtypes_pkg::*;

// FIR taps
import alpaca_ospfb_hann_2048_8_coeff_pkg::*;
//import alpaca_ospfb_hann_512_8_coeff_pkg::*;
//import alpaca_ospfb_hann_128_8_coeff_pkg::*;
// Twiddle factors
import alpaca_ospfb_twiddle_n2048_b23_pkg::*;

// TODO: decide if signals other than valid to allow vip to start capturing (e.g., also use last)
parameter int FRAMES = 32;

/***************************************************
  Testbench
***************************************************/

module xpm_adc_ospfb_tb();

logic adc_clk, dsp_clk, rst, en;

alpaca_xfft_status_axis m_axis_fft_status_x2(), m_axis_fft_status_x1();

logic [1:0] event_frame_started;
logic [1:0] event_tlast_unexpected;
logic [1:0] event_tlast_missing;
logic [1:0] event_fft_overflow;
logic [1:0] event_data_in_channel_halt;

logic vip_full;

xpm_ospfb_adc_top #(
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .WK(WK),
  .SRC_PERIOD(ADC_PERIOD),
  .F_SOI_NORM(F_SOI_NORM),
  .ADC_GAIN(ADC_GAIN),
  .ADC_BITS(ADC_BITS),
  .SIGMA_BIT(SIGMA_BIT),
  .DC_FIFO_DEPTH(DC_FIFO_DEPTH),
  .FRAMES(FRAMES)
) DUT (
  .s_axis_aclk(adc_clk),
  .m_axis_aclk(dsp_clk),
  .rst(rst),
  .en(en),
  // fft status signals
  .m_axis_fft_status_x2(m_axis_fft_status_x2),
  .m_axis_fft_status_x1(m_axis_fft_status_x1),
  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt),
  // vip signal
  .vip_full(vip_full)
);

// tasks to wait for a cycle in each clock domain
task wait_adc_cycles(int cycles=1);
  repeat(cycles)
    @(posedge adc_clk);
endtask

task wait_dsp_cycles(int cycles=1);
  repeat(cycles)
    @(posedge dsp_clk);
endtask

// DSP clock generator
int simcycles;
initial begin
  dsp_clk <= 0; simcycles=0;
  forever #(DSP_PERIOD/2) begin
    dsp_clk = ~dsp_clk;
    simcycles += (1 & dsp_clk) & ~DUT.ospfb_inst.datapath_inst.hold_rst;//~rst;
  end
end

// ADC clock generator
int adc_cycles;
initial begin
  adc_clk <= 0; adc_cycles=0;
  forever #(ADC_PERIOD/2) begin
    adc_clk = ~adc_clk;
    adc_cycles += (1 & adc_clk) & ~rst;
  end
end

parameter string cycfmt = $psprintf("%%%0d%0s",4, "d");
string logfmt = $psprintf("%%sCycle=%s:\n\tSLV: %%s\n\tMST: %%s%%s\n", cycfmt);

initial begin
  int errors;
  virtual alpaca_data_pkt_axis #(.TUSER(1)) slv; // view into the data source interface

  slv = DUT.ospfb_inst.s_axis_ospfb;
  errors = 0;

  $display("Cycle=%4d: **** Starting OSPFB test bench ****", simcycles);
  // reset circuit
  rst <= 1;
  wait_dsp_cycles(FFT_LEN*PTAPS); // reset the pipeline
  @(posedge dsp_clk);
  @(negedge dsp_clk) rst = 0; en = 1;

  // wait until we get out of reset from the ospfb (WAIT_FIFO state)
  @(posedge slv.tready);

  $display("Cycle=%4d: Finished init...", simcycles);
  // wait until we have captured the requested number of frames
  // TODO: not using tlast, use this to report status or for ctrl instead full signal
  $display("\nWaiting for OSPFB outputs to fill AXIS capture");
  while (~vip_full) begin
    wait_dsp_cycles(1);
    //$display(logfmt, GRN, simcycles, slv.print(), m_axis_fir.print(), RST);
  end

  // write capture contents for processing
  $writememh("xpm_adc_ospfb_capture_hex.txt", DUT.vip_inst.ram);
  $writememb("xpm_adc_ospfb_capture_bin.txt", DUT.vip_inst.ram);

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule : xpm_adc_ospfb_tb
