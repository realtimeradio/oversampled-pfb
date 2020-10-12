`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_sim_constants_pkg::*;
import alpaca_dtypes_pkg::*;
import alpaca_ospfb_ramp_128_8_coeff_pkg::*;

// impulse parameters (although not used...)
parameter int IMPULSE_PHA = DEC_FAC+1;
parameter int IMPULSE_VAL = 128*128;//FFT_LEN*FFT_LEN; //scaling schedule at 1/N

parameter int FRAMES = 2;

/***************************************************
  Testbench
***************************************************/

module xpm_ospfb_tb();

logic adc_clk, dsp_clk, rst, en;

alpaca_xfft_status_axis m_axis_fft_status_x2(), m_axis_fft_status_x1();

logic [1:0] event_frame_started;
logic [1:0] event_tlast_unexpected;
logic [1:0] event_tlast_missing;
logic [1:0] event_fft_overflow;
logic [1:0] event_data_in_channel_halt;

logic vip_full;

// ctr data source --> dual-clock fifo --> ospfb --> axis vip
// xpm_ospfb_ctr_top #(
xpm_ospfb_impulse_top #(
  .SAMP_PER_CLK(SAMP_PER_CLK),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .TAPS(TAPS),
  .TWIDDLE_FILE(TWIDDLE_FILE),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL),
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
  // read in golden data
  sample_t fir_golden[];
  sample_t out_golden[];
  sample_t gin;
  automatic int nread = 1; // add 1 to align the golden data (single sample/clk) data with the added sample delay block
  automatic int size = 100;
  string fname;
  int fp;
  int err;

  virtual alpaca_data_pkt_axis #(.TUSER(1)) slv; // view into the data source interface

  int errors;
  int x_errs;
  int gidx;
  fir_pkt_t gval;
  fir_pkt_t fir_out_re;
  fir_pkt_t fir_out_im;
  fir_pkt_t pc_out_re;
  fir_pkt_t pc_out_im;

  fname = $psprintf("/home/mcb/git/alpaca/oversampled-pfb/python/apps/golden_ctr_%0d_%0d_%0d.dat",
                      FFT_LEN, DEC_FAC, PTAPS);
  fp = $fopen(fname, "rb");
  if (!fp) begin
    $display("could not open data file...");
    $finish;
  end

  fir_golden = new[size];
  out_golden = new[size];
  while(!$feof(fp)) begin
    err = $fscanf(fp, "%u", gin);
    fir_golden[nread] = gin;
    err = $fscanf(fp, "%u", gin);
    out_golden[nread++] = gin;
    if (nread == size-1) begin
      size+=100;
      fir_golden = new[size](fir_golden);
      out_golden = new[size](out_golden);
    end
  end
  nread = nread-2;// subtract one due to the the last increment in the loop and another for sample delay offset
  $fclose(fp);
    
  slv = DUT.ospfb_inst.s_axis_ospfb;
  errors = 0;
  gidx = 0;

  $display("Cycle=%4d: **** Starting OSPFB test bench ****", simcycles);
  // reset circuit
  rst <= 1;
  wait_dsp_cycles((FFT_LEN*PTAPS)); // reset the pipeline
  @(posedge dsp_clk);
  @(negedge dsp_clk) rst = 0; en = 1;

  // wait until we get out of reset from the ospfb (INIT and WAITFFT states)
  @(posedge slv.tready);

  $display("Cycle=%4d: Finished init...", simcycles);
  for (int i=0; i < nread; i=i+SAMP_PER_CLK) begin
    wait_dsp_cycles(1);
    // pack single samples from golden source into a `samp_per_clk` word
    gval = 0;
    for (int j=0; j<SAMP_PER_CLK; j++) begin
      gval = (out_golden[gidx++] << (SAMP_PER_CLK-1-j)*$bits(sample_t)) | gval;
    end
    fir_out_re = (DUT.ospfb_inst.datapath_inst.m_axis_fir_re.tready & DUT.ospfb_inst.datapath_inst.m_axis_fir_re.tvalid) ? DUT.ospfb_inst.datapath_inst.m_axis_fir_re.tdata : '0;
    fir_out_im = (DUT.ospfb_inst.datapath_inst.m_axis_fir_im.tready & DUT.ospfb_inst.datapath_inst.m_axis_fir_im.tvalid) ? DUT.ospfb_inst.datapath_inst.m_axis_fir_im.tdata : '0;
    pc_out_re = DUT.ospfb_inst.datapath_inst.sout_re;
    pc_out_im = DUT.ospfb_inst.datapath_inst.sout_im;

    if (pc_out_re === 'x || pc_out_im === 'x) begin
      x_errs++;
      $display("%sT=%4d {expected: 0x%0x, observed: 0x%0x, observed: 0x%0x}%s", RED, simcycles, gval, pc_out_re, pc_out_im, RST);
    end else if (pc_out_re != gval || pc_out_im != gval) begin
      errors++;
      $display("%sT=%4d {expected: 0x%0x, observed: 0x%0x, observed: 0x%0x}%s", RED, simcycles, gval, pc_out_re, pc_out_im, RST);
    end else begin
      $display("%sT=%4d {expected: 0x%0x, observed: 0x%0x, observed: 0x%0x}%s", GRN, simcycles, gval, pc_out_re, pc_out_im, RST);
    end
  end

  // For the counter source the output isn't really valid or used. Primarily the counter has
  // been helpful in diagnosing and comparing polyphase fir structure with the python simulator
  // wait until we have captured the required number of frames
  // note: not using axis tlast, could possibly use that instead of a full signal
  $display("\nWaiting for OSPFB outputs to fill AXIS capture");
  while (~vip_full) begin
     wait_dsp_cycles(1);
  end

  //fp = $fopen("ctr_ospfb_capture.bin", "wb");
  //if (!fp) begin
  //  $display("could not create file...");
  //  $finish;
  //end

  //// write formatted binary
  //for (int i=0; i < SAMP; i++) begin
  //  $fwrite(fp, "%u", DUT.vip_inst.ram[i]); // writes 4 bytes in native endian format
  //end
  //$fclose(fp);

  $display("*** Simulation complete: Errors=%4d X_Errors=%4d***", errors, x_errs);
  // Note the x_errs is meant to catch where the output is not driven correctly because this
  // should techincally still be an error and undesired opeartion. However right now we will
  // always have FFT_LEN x_errs becasue the phasecomp buffer is not initialized and reset
  // correctly.
  $finish;
end

endmodule : xpm_ospfb_tb
