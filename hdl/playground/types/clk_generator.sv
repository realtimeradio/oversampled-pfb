`timescale 1ns/1ps
`default_nettype none

module clk_generator #(
  parameter int PERIOD
) (
  output logic clk
);

  initial begin
    clk <= 0;
    forever #(PERIOD/2) clk = ~clk;
  end

endmodule

