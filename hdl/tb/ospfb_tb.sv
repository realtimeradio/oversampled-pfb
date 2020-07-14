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
logic [WIDTH-1:0] din, dout;

axis #(.WIDTH(WIDTH)) mst(), slv();

// data source for simulation
src_ctr #(
  .WIDTH(WIDTH),
  .MAX_CNT(FFT_LEN),
  .ORDER("natural")
) src_ctr_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(slv)
);

OSPFB #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .SRT_PHA(DEC_FAC-1),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN)
) DUT (
  .clk(clk),
  .rst(rst),
  .en(en),
  .m_axis(mst),
  .s_axis(slv)
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
        sr_sumbuf_h[pp][mm] = DUT.fir.pe[pp].sumbuf.gen_delay.sr[mm].probe.monitor;
        sr_vldbuf_h[pp][mm] = DUT.fir.pe[pp].validbuf.gen_delay.sr[mm].probe.monitor;
      end
    end

    for (mm=0; mm < DATA_NUM; mm++) begin
      initial begin
        sr_databuf_h[pp][mm] = DUT.fir.pe[pp].databuf.gen_delay.sr[mm].probe.monitor;
      end
    end

    for (mm=0; mm < LOOP_NUM; mm++) begin
      initial begin
        sr_loopbuf_h[pp][mm] = DUT.fir.pe[pp].loopbuf.gen_delay.sr[mm].probe.monitor;

      end
    end

    initial begin
      pe_h[pp] = new;
      pe_h[pp].sumbuf = new(DUT.fir.pe[pp].sumbuf.probe.monitor,
                            DUT.fir.pe[pp].sumbuf.headSR.probe.monitor,
                            sr_sumbuf_h[pp]);

      pe_h[pp].vldbuf = new(DUT.fir.pe[pp].validbuf.probe.monitor,
                            DUT.fir.pe[pp].validbuf.headSR.probe.monitor,
                            sr_vldbuf_h[pp]);

      pe_h[pp].databuf = new(DUT.fir.pe[pp].databuf.probe.monitor,
                             DUT.fir.pe[pp].databuf.headSR.probe.monitor,
                             sr_databuf_h[pp]);

      pe_h[pp].loopbuf = new(DUT.fir.pe[pp].loopbuf.probe.monitor,
                             DUT.fir.pe[pp].loopbuf.headSR.probe.monitor,
                             sr_loopbuf_h[pp]);

      pe_h[pp].mac = DUT.fir.pe[pp].probe.monitor;

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
  errors = 0;
  gidx = 0;

  $display("Cycle=%4d: **** Starting OSPFB test bench ****", simcycles);
  // reset circuit
  rst <= 1;
  wait_cycles(299); // reset the pipeline
  @(posedge clk);
  @(negedge clk) rst = 0; en = 1;

  $display("Cycle=%4d: Finished init...", simcycles);
  for (int i=0; i < nread; i++) begin // 10*FFT_LEN+1; i++) begin
    wait_cycles(1);
    //$display(logfmt, GRN, simcycles, rst, en, slv.tdata, mst.tdata, RST);
    $display(logfmt, GRN, simcycles, slv.print(), mst.print(), RST);
    ospfb.monitor();
    gval = out_golden[gidx++];
    if (mst.tdata != gval) begin
      errors++;
      $display("%s{expected: 0x%0x, observed: 0x%0x}%s", RED, gval, mst.tdata, RST);
    end else begin
      $display("%s{expected: 0x%0x, observed: 0x%0x}%s", GRN, gval, mst.tdata, RST);
    end
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule
