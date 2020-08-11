`timescale 1ns/1ps
`default_nettype none

module PE_ShiftReg #(DEPTH=16, WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

// used to reset/load values to prevent fan out
logic [WIDTH-1:0] headReg;

logic [(DEPTH-1)*WIDTH-1:0] shiftReg;
//logic [WIDTH-1:0] tmp_dout;

always_ff @(posedge clk)
  if (rst)
    headReg <= '0;
  else if (en)
    headReg <= din;
  else
    headReg <= headReg;

always_ff @(posedge clk)
  shiftReg <= {shiftReg[(DEPTH-2)*WIDTH:0], headReg};

always_ff @(posedge clk)
  //tmp_dout <= shiftReg[(DEPTH-1)*WIDTH-1:(DEPTH-2)*WIDTH];
  dout <= shiftReg[(DEPTH-1)*WIDTH-1:(DEPTH-2)*WIDTH];
  
//assign dout = tmp_dout;

endmodule
