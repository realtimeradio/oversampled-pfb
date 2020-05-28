`timescale 1ns / 1ps
`default_nettype none

`define BRANCH 8 // M
`define RATE 6     // D
`define DEPTH `BRANCH*2 // 2M

`define PERIOD 10
`define WIDTH 16

`define RED "\033\[0;31m"
`define GRN "\033\[0;32m"
`define RST "\033\[0m"

module phasecomp_tb();

// simulation signals
logic clk, rst;
logic [`WIDTH-1:0] din, dout; // din will start off as a simple counter

// instantiate DUT
PhaseComp #(
  .DEPTH(`DEPTH),
  .WIDTH(`WIDTH)
) DUT (.*);

// Next steps:
// 1). Get the shift offset variable to work correctly (signed rollover)
// 2). are there math packages that offer fft? I remember using sine in the ADC,
//     should check that one out
// function and simulation tasks
function automatic void chkram();
  $display("**** RAM contents ****");
  for (int i=0; i < `DEPTH; i++) begin
    if (i==0)
      $display("A\t{Addr: 0x%04X, data: 0x%04X}<-- bottom", i, DUT.ram[i]);
    else if (i==8)
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
  int shiftStates[4]; // TODO: how to get this dynamic and have NStates be the variable

  // constructor
  function new(int M);
    this.M = M;
    n = 0;                              // decimated time sample
    r = 0;                              // current state index
    modtimer = 0;                       // right now, a mod counter to keep track AND the branch index
    NStates = 4;
    shiftStates = '{0, 6, 4, 2}; // M=8, D=6 phase rotation states
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
  forever #(`PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk);
  end
end

// initialize RAM
initial begin
  for (int i=0; i < `DEPTH; i++) begin
    DUT.ram[i] = '0;
  end
end


// begin simulation
int truth;
int errors;
initial begin
  Source s;
  Sink   k;
  s = new(`BRANCH);
  k = new(`BRANCH);
  errors = 0;

  $display("Cycle=%4d: **** Starting PhaseComp test bench ****", simcycles);
  // reset circuit
  rst <= 1; din <= s.createSample();
  @(posedge clk);
  @(negedge clk) rst = 0;

  $display("Cycle=%4d: Finished init, initial ram contents...", simcycles);
  chkram();

  // feed samples to pass wind-up latency. The latency of the phase compensation
  // should be M (BRANCH)
  $display("Cycle=%4d: {FSM State: %8s}", simcycles, DUT.cs.name);
  $display("Cycle=%4d: Loading %4d samples for initial wind up...", simcycles, `BRANCH);
  for (int i=0; i < `BRANCH; i++) begin
    $display("Cycle=%4d: {State: %8s, din: 0x%04X, cs_wAddr: 0x%04X, cs_rAddr: 0x%04X, shiftOffset=0x%04X, incShift=0b%1b}\n",
                                simcycles, DUT.cs.name, DUT.din, DUT.cs_wAddr, DUT.cs_rAddr, DUT.shiftOffset, DUT.incShift);
    wait_cycles(1);
    din = s.createSample();
    #(1ns); // move off edge to monitor
  end

  // after M (BRANCH) cycles start verifying output
  $display("Cycle=%4d: beginning to verify results...", simcycles);
  for (int i=0; i < 20*`DEPTH; i++) begin
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

  $finish;
end

endmodule // phasecomp_tb()
