`timescale 1ns/1ps
`default_nettype none


parameter PERIOD = 10;

parameter DEPTH = 8;
parameter WIDTH = 4;

parameter NUM = 2;

module shiftreg_tb();

logic clk, rst, en;
logic [WIDTH-1:0] din, dout;

// PE_ShiftReg #(
//   .DEPTH(DEPTH),
//   .WIDTH(WIDTH)
// ) DUT (.*);

// GenShiftReg #(
//   .NUM(NUM),
//   .DEPTH(DEPTH),
//   .WIDTH(WIDTH)
// ) DUT (.*);

ShiftRegArr #(
  .NUM(NUM),
  .DEPTH(DEPTH),
  .WIDTH(WIDTH)
) DUT (.*);

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


function void puts(int cycles, string s);
   $display("Cycle=%4d: %s", cycles, s);
endfunction

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
  s = new(DEPTH);
  errors = 0;

  $display("Cycle=%4d: **** Starting PE_ShiftReg test bench ****", simcycles);
  $display(regfmt,12);
  // reset circuit
  rst <= 1; din <= s.createSample();
  @(posedge clk);
  @(negedge clk) rst = 0; en = 1;

  $display("Cycle=%4d: Finished init...", simcycles);
  //$display("Cycle=%4d: {en: 0b%1b, din: 0x%04X, head: 0x%01X, reg: 0x%07X, dout: 0x%04X}", simcycles, en, din, DUT.headReg, DUT.shiftReg, dout);
  //$display(logfmt, simcycles, en, din, DUT.generate_delayline[1].shiftReg, DUT.headReg, dout);
  //$display(logfmt, simcycles, en, din, DUT.generate_delayline[2].shiftReg, DUT.headReg, dout);
  //$display(logfmt, simcycles, en, din, DUT.shiftReg, DUT.headReg, dout);
  for (int i=0; i < NUM-1; i++) begin
    $display("0x%07X", DUT.pe[i].shiftReg);
  end
  for (int i=0; i < 4*DEPTH; i++) begin
    wait_cycles(1);
    din = s.createSample();
    #(1ns); // move off edge to monitor
    //$display("Cycle=%4d: {en: 0b%1b, din: 0x%04X, reg: 0x%08X, dout: 0x%04X}", simcycles, en, din, DUT.shiftReg, dout);
    //$display(logfmt, simcycles, en, din, DUT.generate_delayline[1].shiftReg, DUT.headReg, dout);
    //$display(logfmt, simcycles, en, din, DUT.generate_delayline[2].shiftReg, DUT.headReg, dout);
    //$display(logfmt, simcycles, en, din, DUT.shiftReg, DUT.headReg, dout);
    $display("0x%07X", DUT.pe[1].shiftReg);
    $display("0x%07X", DUT.pe[2].shiftReg);
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule


