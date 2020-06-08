`timescale 1ns/1ps
`default_nettype none

parameter PERIOD = 10;

parameter DEPTH = 8;
parameter WIDTH = 4;

parameter NUM = 2;

module if_tb();

logic clk, rst, en;
logic [WIDTH-1:0] din;
logic [NUM*WIDTH-1:0] dout;

 PE_ShiftReg #(
   .DEPTH(DEPTH),
   .WIDTH(WIDTH)
 ) DUT[0:NUM-1] (.*);

// note that I don't need the genvar I could have done the bind syntax that
// targets all PE_ShiftReg modules
// bind PE_ShiftReg srif #(...) ifsr (...);
// and would work just fine
genvar ii;
generate
  for (ii=0; ii<NUM; ii++) begin

    bind PE_ShiftReg : DUT[ii] srif #(
                            .DEPTH(DEPTH),
                            .WIDTH(WIDTH)
                       ) ifsr (.sr(shiftReg), .clk);
  end
endgenerate

task wait_cycles(input int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

initial begin
  clk <= 0;
  forever #(PERIOD/2) clk = ~clk;
end

initial begin
  rst <= 1; din <= 4'b0011;
  @(posedge clk);
  @(negedge clk) rst = 0; en = 1;

  for (int i=0; i<4*DEPTH; i++) begin
    wait_cycles(1);
    //$display("0x%07X", DUT.ifsr.get_sr());
    din = din+1;
  end
  $finish;
end

endmodule
