`timescale 1ns / 1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_sim_constants_pkg::*;
import alpaca_dtypes_pkg::*;
import alpaca_ospfb_ix_pkg::*;
import alpaca_ospfb_utils_pkg::*;

parameter int DEPTH = FFT_LEN*2;          // 2M
parameter int TB_SAMP_PER_CLK = 1;

parameter int GCD = gcd(FFT_LEN, DEC_FAC);
parameter int NUM_STATES = FFT_LEN/GCD;

module phasecomp_tb();

// simulation signals
logic clk, rst;

alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(TB_SAMP_PER_CLK), .TUSER(1)) src_to_dut(), mst();

src_ctr #(
  .WIDTH(WIDTH),
  .MAX_CNT(FFT_LEN),
  .ORDER("processing")
) src_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(src_to_dut)
);

// instantiate DUT
PhaseComp #(
  .DEPTH(DEPTH),
  .DEC_FAC(DEC_FAC),
  .SAMP_PER_CLK(TB_SAMP_PER_CLK)
) DUT (
  .clk(clk),
  .rst(rst),
  .din(src_to_dut.tdata),
  .dout(mst.tdata)
);

// bind monitor
//bind PhaseComp ram_if #(
//                   .WIDTH(WIDTH),
//                   .DEPTH(DEPTH)
//                 ) probe (
//                   .clk(clk),
//                   .ram(ram),
//                   .state(cs),
//                   .din(din),
//                   .cs_wAddr(cs_wAddr),
//                   .cs_rAddr(cs_rAddr),
//                   .shiftOffset(shiftOffset),
//                   .incShift(incShift) 
//                 );

function automatic void chkram();
  $display("**** RAM contents ****");
  for (int i=0; i < DEPTH; i++) begin
    if (i==0)
      $display("A\t{Addr: 0x%04X, data: 0x%04X}<-- bottom", i, DUT.ram[i]);
    else if (i==FFT_LEN)
      $display("B\t{Addr: 0x%04X, data: 0x%04X}<-- bottom", i, DUT.ram[i]);
    else
      $display("\t{Addr: 0x%04X, data: 0x%04X}", i, DUT.ram[i]);
  end
  $display("");
endfunction // chkram

task wait_cycles(input int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

// start clk and cycle counter
int simcycles;
initial begin
  clk <= 0; simcycles=0;
  forever #(PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk) & ~rst;
  end
end

parameter string cycfmt = $psprintf("%%%0d%0s",4, "d");
string logfmt = $psprintf("%%sCycle=%s:\n\tSLV: %%s\n\tMST: %%s%%s\n", cycfmt);

// main initial block
initial begin
  probe #(.WIDTH(WIDTH), .DEPTH(DEPTH)) pc_monitor_h;
  Source s;
  Sink   k;
  int truth;
  int errors;
  string vldmsg;

  //pc_monitor_h = DUT.probe.monitor;

  s = new(FFT_LEN);
  k = new(FFT_LEN, NUM_STATES);
  errors = 0;
  vldmsg = "%sCycle=%4d: {expected: 0x%04X, observed: 0x%04X}%s\n";

  $display("Cycle=%4d: **** Starting PhaseComp test bench ****", simcycles);
  // reset circuit
  rst <= 1;
  @(posedge clk);
  @(negedge clk) rst = 0; src_to_dut.tready = 1;

  $display("Cycle=%4d: Finished init...", simcycles);

  // feed samples to pass wind-up latency. The latency of the phase compensation
  // should be M (BRANCH)
  $display("Cycle=%4d: Loading %4d samples for initial wind up...", simcycles, FFT_LEN);
  for (int i=0; i < FFT_LEN; i++) begin
    wait_cycles(1);
    $display(logfmt, GRN, simcycles, src_to_dut.print(), mst.print(), RST);
    //#1ns; // what is the right thing to do with monitoring...
    //$display(pc_monitor_h.peek());
  end

  // after M (BRANCH) cycles start verifying output
  $display("Cycle=%4d: beginning to verify results...", simcycles);
  for (int i=0; i < 2*DEPTH; i++) begin
    wait_cycles(1);
    $display(logfmt, GRN, simcycles, src_to_dut.print(), mst.print(), RST);
    //$display(pc_monitor_h.peek());

    truth = k.outputTruth();
    if (truth != mst.tdata) begin
      errors++;
      $display(vldmsg, RED, simcycles, truth, mst.tdata, RST);
    end else begin
      $display(vldmsg, GRN, simcycles, truth, mst.tdata, RST);
    end

  end
  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule // phasecomp_tb()
