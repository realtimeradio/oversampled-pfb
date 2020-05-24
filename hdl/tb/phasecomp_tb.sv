`timescale 1ns / 1ps
`default_nettype none

`define BRANCH 8 // M
`define RATE 6     // D
`define DEPTH `BRANCH*2 // 2M

`define PERIOD 10
`define WIDTH 16

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
function void chkram();
  $display("**** RAM contents ****");
  for (int i=0; i < `DEPTH; i++) begin
    $display("\t{Addr: 0x%04X, data: 0x%04X}", i, DUT.ram[i]);
  end
  $display("");
endfunction // chkram


class Source;
  int M, i, modtimer;

  // constructor
  function new(int M);
    this.M = M;
    i = 1;
    modtimer = 0; 
  endfunction

  // class methods
  function int createSample();
    dout = i*M - modtimer - 1;

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
initial begin
  Source s;
  s = new(`BRANCH);

  $display("Cycle=%4d: **** Starting PhaseComp test bench ****", simcycles);

  // reset circuit
  rst <= 1; din <= s.createSample();
  @(posedge clk);
  @(negedge clk) rst = 0;

  $display("Cycle=%4d: Finished init, initial ram contents...", simcycles);
  chkram();
  $display("Cycle=%4d: {FSM State: %8s}", simcycles, DUT.cs.name);
  $display("Cycle=%4d: loading samples...", simcycles);
  for (int i=0; i < 2*`DEPTH; i++) begin
    wait_cycles(1);
    #(1ns); // move off edge to monitor
    $display("Cycle=%4d: Checking ram and output...", simcycles);
    chkram();
    din = s.createSample();
  end

  $finish;
end

endmodule // phasecomp_tb()
