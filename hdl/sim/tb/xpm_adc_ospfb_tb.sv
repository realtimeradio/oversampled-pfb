`timescale 1ns/1ps
`default_nettype none

import alpaca_ospfb_monitor_pkg::*;
import alpaca_ospfb_constants_pkg::*;
import alpaca_ospfb_hann_2048_8_coeff_pkg::*;

parameter DEPTH = FFT_LEN;
parameter NUM = DEPTH/SRLEN - 1;
parameter LOOP_NUM = (FFT_LEN-DEC_FAC)/SRLEN - 1;
parameter DATA_NUM = 2*DEPTH/SRLEN-1;

// TODO: need to figure out how to indicate to axis vip it should start capturing
parameter int FRAMES = 32;
parameter int SAMP = FRAMES*FFT_LEN;

// dc fifo parameters
parameter int FIFO_DEPTH = FFT_LEN/2;
parameter int PROG_EMPTY_THRESH = FIFO_DEPTH/2;
parameter int PROG_FULL_THRESH = FIFO_DEPTH/2;

module xpm_adc_ospfb_tb();

logic adc_clk, dsp_clk, rst, en;

logic event_frame_started;
logic event_tlast_unexpected;
logic event_tlast_missing;
logic event_fft_overflow;
logic event_data_in_channel_halt;

logic almost_empty, almost_full, prog_empty, prog_full;
logic [$clog2(FIFO_DEPTH)-1:0] rd_count, wr_count;

logic vip_full;

axis #(.WIDTH(FFT_STAT_WID)) m_axis_fft_status();

// adc model data source --> dual clock fifo --> xpm_ospfb --> axis vip
xpm_ospfb_adc_top #(
  .SRC_PERIOD(ADC_PERIOD),
  .ADC_BITS(ADC_BITS),
  .WIDTH(WIDTH),
  .FFT_LEN(FFT_LEN),
  .SAMP(SAMP),
  .BASE_COEF_FILE(BASE_COEF_FILE),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN),
  .TAPS(TAPS),
  .CONF_WID(FFT_CONF_WID),
  .FIFO_DEPTH(FIFO_DEPTH),
  .PROG_EMPTY_THRESH(PROG_EMPTY_THRESH),
  .PROG_FULL_THRESH(PROG_FULL_THRESH)
) DUT (
  .clka(adc_clk),
  .clkb(dsp_clk),
  .rst(rst),
  .en(en),
  // fft signals
  .m_axis_fft_status(m_axis_fft_status),

  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt),
  // fifo signals
  .almost_empty(almost_empty),
  .almost_full(almost_full),
  .prog_empty(prog_empty),
  .prog_full(prog_full),
  .rd_count(rd_count),
  .wr_count(wr_count),
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
    simcycles += (1 & dsp_clk) & ~DUT.ospfb_inst.hold_rst;//~rst;
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

  slv = DUT.s_axis_ospfb;
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

  fp = $fopen("xpm_adc_ospfb_capture.bin", "wb");
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
