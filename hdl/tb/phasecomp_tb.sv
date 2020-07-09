`timescale 1ns / 1ps
`default_nettype none

import alpaca_ospfb_utils_pkg::*;

parameter int DEPTH = FFT_LEN*2;          // 2M
parameter int WIDTH = 32;                 // sample bit width

parameter int GCD = gcd(FFT_LEN, DEC_FAC);
parameter int NUM_STATES = FFT_LEN/GCD;

module phasecomp_tb();

// simulation signals
logic clk, rst;
logic [WIDTH-1:0] din, dout; // din will start off as a simple counter

// instantiate DUT
PhaseComp #(
  .DEPTH(DEPTH),
  .WIDTH(WIDTH),
  .DEC_RATE(DEC_FAC)
) DUT (.*);

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
    simcycles += (1 & clk);
  end
end

// initialize RAM
initial begin
  for (int i=0; i < DEPTH; i++) begin
    DUT.ram[i] = '0;
  end
end

// main initial block
int truth;
int errors;
initial begin
  Source s;
  Sink   k;
  s = new(FFT_LEN);
  k = new(FFT_LEN, NUM_STATES);
  errors = 0;

  $display("Cycle=%4d: **** Starting PhaseComp test bench ****", simcycles);
  $display("FFT_LEN=%4d", FFT_LEN);
  $display("OSRATIO=%g", OSRATIO);
  $display("DEC_FAC=%4d", DEC_FAC);
  $display("GCD=%4d", GCD);
  $display("NUM_STATES=%4d", NUM_STATES);
  // reset circuit
  rst <= 1; din <= s.createSample();
  @(posedge clk);
  @(negedge clk) rst = 0;

  $display("Cycle=%4d: Finished init, initial ram contents...", simcycles);
  chkram();

  // feed samples to pass wind-up latency. The latency of the phase compensation
  // should be M (BRANCH)
  $display("Cycle=%4d: {FSM State: %8s}", simcycles, DUT.cs.name);
  $display("Cycle=%4d: Loading %4d samples for initial wind up...", simcycles, FFT_LEN);
  for (int i=0; i < FFT_LEN; i++) begin
    $display("Cycle=%4d: {State: %8s, din: 0x%04X, cs_wAddr: 0x%04X, cs_rAddr: 0x%04X, shiftOffset=0x%04X, incShift=0b%1b}\n",
                                simcycles, DUT.cs.name, DUT.din, DUT.cs_wAddr, DUT.cs_rAddr, DUT.shiftOffset, DUT.incShift);
    wait_cycles(1);
    din = s.createSample();
    #(1ns); // move off edge to monitor
  end

  // after M (BRANCH) cycles start verifying output
  $display("Cycle=%4d: beginning to verify results...", simcycles);
  for (int i=0; i < 20*DEPTH; i++) begin
    //$display("Cycle=%4d: {State: %8s, din: 0x%04X, cs_wAddr: 0x%04X, cs_rAddr: 0x%04X, shiftOffset=0x%04X, incShift=0b%1b}\n",
    //                            simcycles, DUT.cs.name, DUT.din, DUT.cs_wAddr, DUT.cs_rAddr, DUT.shiftOffset, DUT.incShift);

    wait_cycles(1);
    //chkram();
    din = s.createSample();
    #(1ns); // move off edge to monitor
    truth = k.outputTruth();
    if (truth != dout) begin
      errors++;
      $display("%sCycle=%4d: {expected: 0x%04X, observed: 0x%04X}%s\n", RED, simcycles, truth, dout, RST);
    end else begin
      $display("%sCycle=%4d: {expected: 0x%04X, observed: 0x%04X}%s\n", GRN, simcycles, truth, dout, RST);
    end

  end
  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule // phasecomp_tb()
