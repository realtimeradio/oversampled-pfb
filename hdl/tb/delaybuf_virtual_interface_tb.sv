`timescale 1ns/1ps
`default_nettype none

import alpaca_ospfb_monitor_pkg::*;
// display constants
parameter RED = "\033\[0;31m";
parameter GRN = "\033\[0;32m";
parameter RST = "\033\[0m";

// TODO: this is the third testbench... really should invest in writing packages, monitor,
// interface, drivers, etc so that I can reuse testbenches

parameter PERIOD = 10;
 
// TODO: I am not liking SRLEN and DEPTH being thrown around... starting to cause errors
// and confusion... 
parameter DEPTH = 256;
parameter SRLEN = 64;
parameter WIDTH = 16;

parameter NUM = DEPTH/SRLEN-1;

module delaybuf_tb();

logic clk, rst, en;
logic [WIDTH-1:0] din, dout;

delayline_ix #(.WIDTH(WIDTH)) dix(.clk(clk)); 

DelayBuf #(
  .DEPTH(DEPTH),
  .SRLEN(SRLEN),
  .WIDTH(WIDTH)
) DUT (.clk(clk),
       .rst(dix.rst),
       .en(dix.en),
       .din(dix.din),
       .dout(dix.dout)
);

// note: bind places the instantiation in the target so the passed in `DEPTH` and `WIDTH`
// keyworkds will be placed with the parameter passed in the the target module. Therefore in
// this case DEPTH is the SRLShiftReg depth DelayBuf SRLEN -> SRLShiftReg DEPTH = 8 not the 24
// defined above
bind SRLShiftReg srif #(
                    .DEPTH(DEPTH),
                    .WIDTH(WIDTH)
                 ) probe (.sr(shiftReg), .clk);

bind DelayBuf srif #(
                  .DEPTH(1),
                  .WIDTH(WIDTH)
              ) probe (.sr(headReg), .clk);

parameter string cycfmt = $psprintf("%%%0d%0s",4, "d");
parameter string binfmt = $psprintf("%%%0d%0s",1, "b");
parameter string datfmt = $psprintf("%%%0d%0s",WIDTH, "X");
parameter string regfmt = $psprintf("%%%0d%0s",SRLEN, "X");
parameter string hedfmt = $psprintf("%%%0d%0s",1, "X");

typedef virtual delayline_ix #(.WIDTH(WIDTH)) dbX_t;                // primarydriving interface
typedef virtual srif #(.DEPTH(1), .WIDTH(WIDTH))       hr_probe_t;  // the dbif bound in the delaybuf
typedef virtual srif #(.DEPTH(SRLEN-1), .WIDTH(WIDTH)) hsr_probe_t; // the ifsr bound to the headSR
typedef virtual srif #(.DEPTH(SRLEN), .WIDTH(WIDTH))   sr_probe_t;  // the ifsr bound to the NUM array of shift regs

class Monitor;
  dbX_t mainX_h;
  hr_probe_t hr_h;
  hsr_probe_t hsr_h;
  sr_probe_t sr_h [];
  string logfmt = $psprintf("Cycle=%s: {rst: 0b%s, en: 0b%s, din: 0x%s, dout: 0x%s}",
                                  cycfmt, binfmt, binfmt, datfmt, datfmt);

  function new(dbX_t ix, hr_probe_t headReg, hsr_probe_t headShiftReg, const ref sr_probe_t shiftRegs[NUM]);
    this.mainX_h = ix;
    this.hr_h = headReg;
    this.hsr_h = headShiftReg;
    this.sr_h = new[NUM];
    this.sr_h = shiftRegs;
  endfunction

  function void print_reg();
    string regs;
    for (int i=$size(sr_h)-1; i >= 0; i--) begin
      regs = {regs, $psprintf(" 0x%016X", sr_h[i].sr)};
    end
    regs = {regs, $psprintf(" 0x%015X", hsr_h.sr), $psprintf(" 0x%01X", hr_h.sr)};
    $display(logfmt, simcycles, mainX_h.rst, mainX_h.en, mainX_h.din, mainX_h.dout);
    $display({regs, "\n"});
  endfunction

endclass // Monitor

class Source;
  int M, i, modtimer;

  // constructor
  function new(int M);
    this.M = M;
    i = 1; // processing order
    //i = 0; // natural order
    modtimer = 0; 
  endfunction

  // class methods
  function int createSample();
    int dout = i*M - modtimer - 1; // processing order
    //int dout = i*M + modtimer; // natural order
    // increment meta data
    modtimer = (modtimer + 1) % M;
    i = (modtimer == 0) ? i+1 : i;
    return dout;
  endfunction
endclass // Source

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

// TODO: any race condition concerns using initial blocks to access the probe like this?
sr_probe_t sr_h[NUM];
genvar mm;
generate
  for (mm=0; mm < NUM; mm++) begin
    initial begin
      sr_h[mm] = DUT.gen_delay.sr[mm].probe;
    end
  end
endgenerate

string vstr = "%sCycle=%4d: {expected: 0x%04X, observed: 0x%04X}%s\n";
initial begin
  Source src;
  Source sink;
  Monitor m;

  int errors;
  logic [WIDTH-1:0] truth;

  dbX_t dbx;
  dbx = dix;

  src = new(DEPTH);
  sink = new(DEPTH);
  m = new(dbx, DUT.probe, DUT.headSR.probe, sr_h);

  errors = 0;

  $display("Cycle=%4d: **** Starting PE_ShiftReg test bench ****", simcycles);
  $display("NUM=%0d", NUM);

  // reset circuit
  dix.rst <= 1; dix.din <= src.createSample();
  @(posedge clk);
  @(negedge clk) dix.rst = 0; dix.en = 1;

  $display("Cycle=%4d: Finished init...", simcycles);
  m.print_reg();
  // DEPTH-1 gets us to the DEPTH cycle when the first sample should be on its way out (right?)
  for (int i=0; i < DEPTH-1; i++) begin
    wait_cycles(1);
    #(1ns); // move off edge to monitor (or is it really we move off to drive)?
    m.print_reg();
    dix.din = src.createSample();
  end

  $display("Cycle=%4d: beginning to verify results...", simcycles);
  // from here the sink should produce the same samples as we read out
  for (int i=0; i < 2*DEPTH; i++) begin
    wait_cycles(1);
    #(1ns);
    m.print_reg();
    dix.din = src.createSample();
    truth = sink.createSample();
    if (truth != dix.dout) begin
      errors++;
      $display(vstr, RED, simcycles, truth, dix.dout, RST);
    end else begin
      $display(vstr, GRN, simcycles, truth, dix.dout, RST);
    end
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule


