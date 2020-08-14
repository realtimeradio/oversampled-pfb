`timescale 1ns/1ps
`default_nettype none

import alpaca_ospfb_monitor_pkg::*;
import alpaca_ospfb_constants_pkg::*;

parameter DEPTH = FFT_LEN;
parameter NUM = DEPTH/SRLEN - 1;
parameter LOOP_NUM = (FFT_LEN-DEC_FAC)/SRLEN - 1;
parameter DATA_NUM = 2*DEPTH/SRLEN-1;

parameter int SAMP = 64;

parameter int FIFO_DEPTH = FFT_LEN/2;
parameter int PROG_EMPTY_THRESH = FIFO_DEPTH/2;
parameter int PROG_FULL_THRESH = FIFO_DEPTH/2;

module ospfb_tb();

logic adc_clk, dsp_clk, rst, en;

logic event_frame_started;
logic event_tlast_unexpected;
logic event_tlast_missing;
logic event_fft_overflow;
logic event_data_in_channel_halt;

logic almost_empty, almost_full, prog_empty, prog_full;
logic [$clog2(FIFO_DEPTH)-1:0] rd_count, wr_count;

logic vip_full;

axis #(.WIDTH(8)) m_axis_fft_status();

// ctr data source --> dual clock fifo --> ospfb --> axis vip
ospfb_ctr_top #(
  .WIDTH(WIDTH),
  .FFT_LEN(FFT_LEN),
  .ORDER("natural"),
  .COEFF_WID(COEFF_WID),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN),
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

BindFiles bf();

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

pe_t pe_h[PTAPS];
/*
  TODO: Why do I need the packed array? I know it has to do with references (pointers in a C
  sense) but why can I not use a single array to hold the reference to pass to the constructor.
  Instead to get the correct handle I needed to create a packed array to store all the handles
  at one time.
*/
//sr_probe_t sr_sumbuf_h[PTAPS][NUM];
//sr_probe_t sr_databuf_h[PTAPS][DATA_NUM];
//sr_probe_t sr_loopbuf_h[PTAPS][LOOP_NUM];

import alpaca_ospfb_ix_pkg::probe;
probe #(.WIDTH(WIDTH), .DEPTH(SRLEN)) sr_sumbuf_h[PTAPS][NUM];
probe #(.WIDTH(1), .DEPTH(SRLEN))     sr_vldbuf_h[PTAPS][NUM];
probe #(.WIDTH(WIDTH), .DEPTH(SRLEN)) sr_loopbuf_h[PTAPS][LOOP_NUM];
probe #(.WIDTH(WIDTH), .DEPTH(SRLEN)) sr_databuf_h[PTAPS][DATA_NUM];

genvar pp;
genvar mm;
generate
  for (pp=0; pp < PTAPS; pp++) begin
    for (mm=0; mm < NUM; mm++) begin
      initial begin
        sr_sumbuf_h[pp][mm] = DUT.ospfb_inst.fir_re.pe[pp].sumbuf.gen_delay.sr[mm].probe.monitor;
        sr_vldbuf_h[pp][mm] = DUT.ospfb_inst.fir_re.pe[pp].validbuf.gen_delay.sr[mm].probe.monitor;
      end
    end

    for (mm=0; mm < DATA_NUM; mm++) begin
      initial begin
        sr_databuf_h[pp][mm] = DUT.ospfb_inst.fir_re.pe[pp].databuf.gen_delay.sr[mm].probe.monitor;
      end
    end

    for (mm=0; mm < LOOP_NUM; mm++) begin
      initial begin
        sr_loopbuf_h[pp][mm] = DUT.ospfb_inst.fir_re.pe[pp].loopbuf.gen_delay.sr[mm].probe.monitor;

      end
    end

    initial begin
      pe_h[pp] = new;
      pe_h[pp].sumbuf = new(DUT.ospfb_inst.fir_re.pe[pp].sumbuf.probe.monitor,
                            DUT.ospfb_inst.fir_re.pe[pp].sumbuf.headSR.probe.monitor,
                            sr_sumbuf_h[pp]);

      pe_h[pp].vldbuf = new(DUT.ospfb_inst.fir_re.pe[pp].validbuf.probe.monitor,
                            DUT.ospfb_inst.fir_re.pe[pp].validbuf.headSR.probe.monitor,
                            sr_vldbuf_h[pp]);

      pe_h[pp].databuf = new(DUT.ospfb_inst.fir_re.pe[pp].databuf.probe.monitor,
                             DUT.ospfb_inst.fir_re.pe[pp].databuf.headSR.probe.monitor,
                             sr_databuf_h[pp]);

      pe_h[pp].loopbuf = new(DUT.ospfb_inst.fir_re.pe[pp].loopbuf.probe.monitor,
                             DUT.ospfb_inst.fir_re.pe[pp].loopbuf.headSR.probe.monitor,
                             sr_loopbuf_h[pp]);

      pe_h[pp].mac = DUT.ospfb_inst.fir_re.pe[pp].probe.monitor;

    end

    // initialize filter coeff
    initial begin
      automatic string coeffFile = "coeff/cycramp/h_cycramp_upto_2048.coeff";
      $display("opening %0s", coeffFile);
      $readmemh(coeffFile, DUT.ospfb_inst.fir_re.pe[pp].coeff_ram);
      $readmemh(coeffFile, DUT.ospfb_inst.fir_im.pe[pp].coeff_ram);
    end
  end
endgenerate

parameter string cycfmt = $psprintf("%%%0d%0s",4, "d");
string logfmt = $psprintf("%%sCycle=%s:\n\tSLV: %%s\n\tMST: %%s%%s\n", cycfmt);

initial begin

  // read in golden data
  logic signed [WIDTH-1:0] fir_golden[];
  logic signed [WIDTH-1:0] out_golden[];
  logic signed [WIDTH-1:0] gin;
  automatic int nread = 0;
  automatic int size = 100;
  string fname;
  int fp;
  int err;

  ospfb_t ospfb;
  virtual axis #(.WIDTH(2*WIDTH)) slv; // view into the data source interface

  int errors;
  int x_errs;
  int gidx;
  logic signed [WIDTH-1:0] gval;
  logic signed [WIDTH-1:0] pc_out_re;
  logic signed [WIDTH-1:0] pc_out_im;

  fname = $psprintf("/home/mcb/git/alpaca/oversampled-pfb/python/apps/golden_ctr_%0d_%0d_%0d.dat", FFT_LEN, DEC_FAC, PTAPS); 
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
  --nread; // subtract off the last increment
  $fclose(fp);
    
  ospfb = new(pe_h); //, DUT.phasecomp_inst.probe.monitor);
  //ospfb.pc_monitor = DUT.phasecomp_inst.probe.monitor;
  slv = DUT.s_axis_ospfb;
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
  for (int i=0; i < nread; i++) begin // 10*FFT_LEN+1; i++) begin
    wait_dsp_cycles(1);
    //$display(logfmt, GRN, simcycles, rst, en, slv.tdata, mst.tdata, RST);
    //$display(logfmt, GRN, simcycles, slv.print(), m_axis_fir.print(), RST);
    //ospfb.monitor();
    gval = out_golden[gidx++];
    pc_out_re = DUT.ospfb_inst.sout_re;
    pc_out_im = DUT.ospfb_inst.sout_im;

    if (pc_out_re === 'x || pc_out_im === 'x) begin
      x_errs++;
      $display("%s{expected: 0x%0x, observed: 0x%0x, observed: 0x%0x}%s", RED, gval, pc_out_re, pc_out_im, RST);
    end else if (pc_out_re != gval || pc_out_im != gval) begin
      errors++;
      $display("%s{expected: 0x%0x, observed: 0x%0x, observed: 0x%0x}%s", RED, gval, pc_out_re, pc_out_im, RST);
    end else begin
      $display("%s{expected: 0x%0x, observed: 0x%0x, observed: 0x%0x}%s", GRN, gval, pc_out_re, pc_out_im, RST);
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

  fp = $fopen("ctr_ospfb_capture.bin", "wb");
  if (!fp) begin
    $display("could not create file...");
    $finish;
  end

  // write formatted binary
  for (int i=0; i < SAMP; i++) begin
    $fwrite(fp, "%u", DUT.vip_inst.ram[i]); // writes 4 bytes in native endian format
  end
  $fclose(fp);

  $display("*** Simulation complete: Errors=%4d X_Errors=%4d***", errors, x_errs);
  // Note the x_errs is meant to catch where the output is not driven correctly because this
  // should techincally still be an error and undesired opeartion. However right now we will
  // always have FFT_LEN x_errs becasue the phasecomp buffer is not initialized and reset
  // correctly.
  $finish;
end

endmodule
