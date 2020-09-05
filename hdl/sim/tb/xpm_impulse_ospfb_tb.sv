`timescale 1ns/1ps
`default_nettype none

import alpaca_ospfb_monitor_pkg::*;
import alpaca_ospfb_constants_pkg::*;
import alpaca_ospfb_ones_64_8_coeff_pkg::*;

// impulse parameters
parameter int IMPULSE_PHASE = DEC_FAC+1;
parameter int PULSE_VAL = 1;//FFT_LEN*FFT_LEN; //scaling schedule at 1/N

// TODO: decide if mechanisim other than valid to allow vip to start capturing
parameter int FRAMES = 32;
parameter int SAMP = FRAMES*FFT_LEN;

module xpm_impulse_ospfb_tb();

logic adc_clk, dsp_clk, rst, en;

logic event_frame_started;
logic event_tlast_unexpected;
logic event_tlast_missing;
logic event_fft_overflow;
logic event_data_in_channel_halt;

logic vip_full;

axis #(.WIDTH(FFT_STAT_WID)) m_axis_fft_status();

// impulse data source --> dual-clock fifo --> ospfb --> axis vip
xpm_ospfb_impulse_top #(
  .WIDTH(WIDTH),
  .FFT_LEN(FFT_LEN),
  .COEFF_WID(COEFF_WID),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .FFT_CONF_WID(FFT_CONF_WID),
  .FFT_USER_WID(FFT_USER_WID),
  .IMPULSE_PHASE(IMPULSE_PHASE),
  .PULSE_VAL(PULSE_VAL),
  .DC_FIFO_DEPTH(DC_FIFO_DEPTH),
  .SAMP(SAMP)
) DUT (
  .s_axis_aclk(adc_clk),
  .m_axis_aclk(dsp_clk),
  .rst(rst),
  .en(en),
  // fft signals
  .m_axis_fft_status(m_axis_fft_status),

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

  int fp;
  int errors;
  virtual axis #(.WIDTH(2*WIDTH)) slv; // view into the data source interface

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
    //ospfb.monitor();
  end

  fp = $fopen("xpm_impulse_ospfb_capture.bin", "wb");
  if (!fp) begin
    $display("could not create file...");
    $finish;
  end

  // write formatted binary
  for (int i=0; i < SAMP; i++) begin
    $fwrite(fp, "%u", DUT.vip_inst.ram[i]); // writes 4 bytes in native endian format
  end
  $fclose(fp);

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule