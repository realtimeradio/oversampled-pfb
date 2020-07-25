`timescale 1ns/1ps
`default_nettype none
/*
  TODO: we are now in OSPFB territory meaning we will want some sort of better simulation with
  clock domain crossing by having two clocks generating and processing data
*/

import alpaca_ospfb_monitor_pkg::*;
import alpaca_ospfb_utils_pkg::*;

parameter DEPTH = FFT_LEN;
parameter NUM = DEPTH/SRLEN - 1;
parameter LOOP_NUM = (FFT_LEN-DEC_FAC)/SRLEN - 1;
parameter DATA_NUM = 2*DEPTH/SRLEN-1;

module ospfb_tb();

logic clk, rst, en;

logic event_frame_started;
logic event_tlast_unexpected;
logic event_tlast_missing;
logic event_fft_overflow;
logic event_data_in_channel_halt;

logic vip_full;

axis #(.WIDTH(WIDTH)) m_axis_fir();
axis #(.WIDTH(8)) m_axis_fft_status();

ospfb_ctr_top #(
  .WIDTH(WIDTH),
  .FFT_LEN(FFT_LEN),
  .ORDER("natural"),
  .COEFF_WID(COEFF_WID),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN)
) DUT (
  .clk(clk),
  .rst(rst),
  .en(en),

  .m_axis_fir(m_axis_fir),
  .m_axis_fft_status(m_axis_fft_status),

  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt),

  .vip_full(vip_full)
);

BindFiles bf();

task wait_cycles(input int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

int simcycles;
initial begin
  clk <= 0; simcycles=0;
  forever #(PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk) & ~rst;
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
  int fp;
  int err;

  ospfb_t ospfb;
  virtual axis #(.WIDTH(WIDTH)) slv; // view into the data source interface

  int errors;
  int gidx;
  logic signed [WIDTH-1:0] gval;

  fp = $fopen("/home/mcb/git/alpaca/oversampled-pfb/python/apps/golden_ctr.dat", "rb");
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
  slv = DUT.s_axis;
  errors = 0;
  gidx = 0;

  $display("Cycle=%4d: **** Starting OSPFB test bench ****", simcycles);
  // reset circuit
  rst <= 1;
  wait_cycles(299); // reset the pipeline
  @(posedge clk);
  @(negedge clk) rst = 0; en = 1;

  // wait until we get out of reset from the ospfb (INIT and WAITFFT states)
  @(posedge slv.tready);

  $display("Cycle=%4d: Finished init...", simcycles);
  for (int i=0; i < nread; i++) begin // 10*FFT_LEN+1; i++) begin
    wait_cycles(1);
    //$display(logfmt, GRN, simcycles, rst, en, slv.tdata, mst.tdata, RST);
    $display(logfmt, GRN, simcycles, slv.print(), m_axis_fir.print(), RST);
    ospfb.monitor();
    gval = out_golden[gidx++];
    if (m_axis_fir.tdata[WIDTH-1:0] != gval && m_axis_fir.tdata[2*WIDTH-1:WIDTH] != gval) begin
      errors++;
      $display("%s{expected: 0x%0x, observed: 0x%0x}%s",RED,gval,m_axis_fir.tdata[WIDTH-1:0], RST);
    end else begin
      $display("%s{expected: 0x%0x, observed: 0x%0x}%s",GRN,gval,m_axis_fir.tdata[WIDTH-1:0], RST);
    end
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule
