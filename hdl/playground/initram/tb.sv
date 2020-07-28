`timescale 1ns/1ps
`default_nettype none


module top #(
  parameter int WIDTH=16,
  parameter int DEPTH=16
) (
  input wire logic clk,
  input wire logic wen,
  input wire logic ren,
  input wire logic [$clog2(DEPTH)-1:0] wAddr,
  input wire logic [$clog2(DEPTH)-1:0] rAddr,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0]  dout
);

logic [WIDTH-1:0] ram [DEPTH];

always_ff @(posedge clk)
  if (wen)
    ram[wAddr] <= din;

always_ff @(posedge clk)
  if (ren)
    dout <= ram[rAddr];

endmodule

parameter int PERIOD=10;
parameter int WIDTH=16;
parameter int DEPTH=64;

module testbench();

logic clk, wen, ren;
logic [$clog2(DEPTH)-1:0] wAddr, rAddr;
logic [WIDTH-1:0] din, dout;

top #(
  .WIDTH(WIDTH),
  .DEPTH(DEPTH)
) DUT (.*);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

initial begin
  clk <= 0;
  forever #(PERIOD/2) begin
    clk = ~clk;
  end
end

initial begin
  $readmemh("./coeff/h0.coeff", DUT.ram);
end

initial begin
  wen <= 1'b0; ren <= 1'b0; wAddr <= '0; rAddr <= '0;
  wait_cycles(10);
  @(posedge clk);
  @(negedge clk) wen = 1'b1; wAddr = '0; din = 16'hbeef;

  for (int i=0; i < DEPTH; i++) begin
    $display("0x%0X", DUT.ram[i]);
  end
  $finish;
end

endmodule


