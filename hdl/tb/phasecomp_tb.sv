`timescale 1ns / 1ps
`default_nettype none

// display constants
`define RED "\033\[0;31m"
`define GRN "\033\[0;32m"
`define RST "\033\[0m"

import alpaca_ospfb_utils_pkg::*;

parameter  PERIOD = 10;                   // simulation clk period [ns]

parameter int  FFT_LEN = 2048;              // (M) Polyphase branches
parameter real OSRATIO = 3.0/4.0;         // (D/M) inverse oversample ratio
parameter int  DEC_FAC = FFT_LEN*OSRATIO; // (D) Decimation factor

parameter int DEPTH = FFT_LEN*2;          // 2M
parameter int WIDTH = 32;                 // sample bit width


module phasecomp_tb();

// simulation signals
logic clk, rst;
logic [WIDTH-1:0] din, dout; // din will start off as a simple counter

parameter int GCD = gcd(FFT_LEN, DEC_FAC);
parameter int NUM_STATES = FFT_LEN/GCD;

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

function automatic int mod(input int x, M);
  if (x < 0)
    x = x+M;
  return x % M;
endfunction


//function automatic int outputTruth(input int n, m, r, M);
//  return n*M + mod((m-r),M);
//endfunction

class Source;
  int M, i, modtimer;

  // constructor
  function new(int M);
    this.M = M;
    i = 1; // processing order
    // i = 0; // natural order
    modtimer = 0; 
  endfunction

  // class methods
  function int createSample();
    int dout = i*M - modtimer - 1; // processing order
    // int dout = i*M + modtimer; // natural order
    // increment meta data
    modtimer = (modtimer + 1) % M;
    i = (modtimer == 0) ? i+1 : i;
    return dout;
  endfunction
endclass // Source


// TODO: I am also doing something wrong because Source and Sink are almost
// identical... there should be a better way for reuse...
class Sink;
  int M, m, n, r, modtimer, NStates;
  int shiftStates[];

  // constructor
  function new(int M);
    this.M = M;
    n = 0;                              // decimated time sample
    r = 0;                              // current state index
    modtimer = 0;                       // right now, a mod counter to keep track AND the branch index

    NStates = NUM_STATES;
    shiftStates = new[NStates];
    genShiftStates(shiftStates, FFT_LEN, DEC_FAC);
  endfunction

  // TODO: should we have a check output method or just return a value? i.e.,
  // outputTruth method?  I am iffy on how we would be expecting branch order on
  // the output... I had this nailed down at one point but am since confused
  // again...
  function int outputTruth();
    // man... I am really shooting myself in the foot here with these variable
    // scope issues...  but why should i... isn't it just like python... just
    // get used to it...
    int dout = n*M + mod((modtimer-shiftStates[r]), M);

    // increment meta data 
    modtimer = (modtimer + 1) % M;
    if (modtimer == 0) begin
      n = n+1;
      r = (r+1) % NStates;
    end

    return dout;
  endfunction

endclass //Sink

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


// begin simulation
int truth;
int errors;
initial begin
  Source s;
  Sink   k;
  s = new(FFT_LEN);
  k = new(FFT_LEN);
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
      $display("%sCycle=%4d: {expected: 0x%04X, observed: 0x%04X}%s\n", `RED, simcycles, truth, dout, `RST);
    end else begin
      $display("%sCycle=%4d: {expected: 0x%04X, observed: 0x%04X}%s\n", `GRN, simcycles, truth, dout, `RST);
    end

  end
  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule // phasecomp_tb()
