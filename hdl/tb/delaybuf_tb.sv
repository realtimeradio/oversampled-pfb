`timescale 1ns/1ps
`default_nettype none

// this is the third testbench... really should invest in writing packages, monitor,
// interface, drivers, etc so that I can reuse testbenches

parameter PERIOD = 10;

// I am not liking SRLEN and DEPTH being thrown around... starting to cause errors
// and confusion... 
parameter DEPTH = 16;
parameter SRLEN = 8; 
parameter WIDTH = 4;

parameter NUM = 1;

import abstract_cls::*;

module delaybuf_tb();

logic clk, rst, en;
logic [WIDTH-1:0] din, dout;

DelayBuf #(
  .DEPTH(DEPTH),
  .SRLEN(SRLEN),
  .WIDTH(WIDTH)
) DUT (.*);

bind SRLShiftReg : DUT.headSR srif #(
                                .DEPTH(8-1),
                                .WIDTH(WIDTH)
                              ) ifsr (.sr(shiftReg), .clk);

bind SRLShiftReg : DUT.gen_delay.sr srif #(
                            .DEPTH(8),
                            .WIDTH(WIDTH)
                           ) ifsr (.sr(shiftReg), .clk);

bind DelayBuf : DUT delaybuf_itf #(
                            .WIDTH(WIDTH),
                            .id("1")
                          ) hrif (.hr(headReg), .clk);

class Monitor;
  virtual srif #(.DEPTH(SRLEN-1), .WIDTH(WIDTH)) xif;
  int id;

  function new(virtual srif #(.DEPTH(SRLEN-1), .WIDTH(WIDTH)) xif, int id);
    this.xif = xif;
    this.id = id;
  endfunction

  function void printid();
    $display("connected! id:%0d", id);
  endfunction

  task run;
    fork
    forever
      @(xif.cb) $display("sr:  %0d, 0x%08X", id, xif.get_sr());
    join_none
  endtask
    
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


int errors;

parameter string cycfmt = $psprintf("%%%0d%0s",4, "d");
parameter string binfmt = $psprintf("%%%0d%0s",1, "b");
parameter string datfmt = $psprintf("%%%0d%0s",4, "X");
parameter string regfmt = $psprintf("%%%0d%0s",7, "X");
parameter string hedfmt = $psprintf("%%%0d%0s",1, "X");

string logfmt = $psprintf("Cycle=%s: {en: 0b%s, din: 0x%s, reg: 0x%s, head: 0x%s, dout: 0x%s}", cycfmt, binfmt, datfmt, regfmt, hedfmt, datfmt);
//string logfmt = $psprintf("Cycle=%s: {en: 0b%s, din: 0x%s, head: 0x%s, dout: 0x%s}", cycfmt, binfmt, datfmt, hedfmt, datfmt);

initial begin
  Source s;
  Monitor m1, m2;
  abs_delaybuf_itf #(.WIDTH(WIDTH)) dbitf;
  dbitf = DUT.hrif.ifm;

  s = new(DEPTH);
  m1 = new(DUT.headSR.ifsr, 1);
  m2 = new(DUT.gen_delay.sr.ifsr, 2);
  dbitf.run; // error here? 
  m1.run;
  m2.run; 
  errors = 0;
  //$display("%s, 0x%07X", dbitf.get_id(), dbitf.get_hr());

  $display("Cycle=%4d: **** Starting PE_ShiftReg test bench ****", simcycles);
  // reset circuit
  rst <= 1; din <= s.createSample();
  @(posedge clk);
  @(negedge clk) rst = 0; en = 1;

  $display("Cycle=%4d: Finished init...", simcycles);
  //$display("Cycle=%4d: {en: 0b%1b, din: 0x%04X, head: 0x%01X, reg: 0x%07X, dout: 0x%04X}", simcycles, en, din, DUT.headReg, DUT.shiftReg, dout);
  //$display(logfmt, simcycles, en, din, DUT.shiftReg, DUT.headReg, dout);
  for (int i=0; i < 2*DEPTH; i++) begin
    wait_cycles(1);
    din = s.createSample();
    #(1ns); // move off edge to monitor
    //$display("Cycle=%4d: {en: 0b%1b, din: 0x%04X, reg: 0x%08X, dout: 0x%04X}", simcycles, en, din, DUT.shiftReg, dout);
    //$display(logfmt, simcycles, en, din, DUT.shiftReg, DUT.headReg, dout);
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule


