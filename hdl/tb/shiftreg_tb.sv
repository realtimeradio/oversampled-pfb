`timescale 1ns/1ps
`default_nettype none


parameter PERIOD = 10;

parameter DEPTH = 8;
parameter WIDTH = 4;

module shiftreg_tb();

logic clk, rst, en;
logic [WIDTH-1:0] din, dout;

PE_ShiftReg #(
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

int errors;
initial begin
  Source s;
  s = new(DEPTH);
  errors = 0;

  $display("Cycle=%4d: **** Starting PE_ShiftReg test bench ****", simcycles);

  // reset circuit
  rst <= 1; din <= s.createSample();
  @(posedge clk);
  @(negedge clk) rst = 0; en = 1;

  $display("Cycle=%4d: Finished init...", simcycles);
  $display("Cycle=%4d: {en: 0b%1b, din: 0x%04X, reg: 0x%08X, dout: 0x%04X}", simcycles, en, din, DUT.shiftReg, dout);
  for (int i=0; i < 2*DEPTH; i++) begin
    wait_cycles(1);
    din = s.createSample();
    #(1ns); // move off edge to monitor
    $display("Cycle=%4d: {en: 0b%1b, din: 0x%04X, reg: 0x%08X, dout: 0x%04X}", simcycles, en, din, DUT.shiftReg, dout);
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule


