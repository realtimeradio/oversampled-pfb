`timescale 1ns / 1ps
`default_nettype none

`define PERIOD 10
`define DEPTH 16
`define WIDTH 16

module fifo_tb();

logic clk, rst;
logic [15:0] din, dout;

fifo #(
  .DEPTH(`DEPTH),
  .WIDTH(`WIDTH)
) DUT (.*);

int simcycles;
initial begin
  clk <= 0; simcycles = 0;
  forever #(`PERIOD/2) begin
    clk = ~clk;
    simcycles += (1&clk);
  end
end

initial begin
  for (int i=0; i < 32; i++) begin
    DUT.ram[i] = '0;
  end
end

int cwAddr;
string state;
initial begin
  $display("Cycle=%4d: **** Starting FIFO test bench****", simcycles);
  // reset circuit
  rst <= 1; din <= 0;
  @(posedge clk);
  @(negedge clk) rst = 0;

  $display("Cycle=%4d: Finished init, loading samples.", simcycles);
  for (int i=0; i < 4*`DEPTH; i++) begin
    state = DUT.cs.name;
    wait_cycles(1);
    #(1ns); // move off edge to monitor
    $display("Cycle=%4d: {State :%8s, Mem: 0x%04X, wAddr: 0x%04X, dout: 0x%04X}",
              simcycles, DUT.cs.name, DUT.ram[i%`DEPTH], i%`DEPTH, dout);
    din = din+1;
  end

  $finish;
end

task wait_cycles(input int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

endmodule
