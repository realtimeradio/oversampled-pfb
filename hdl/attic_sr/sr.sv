`timescale 1ns/1ps
`default_nettype none

// moved to attic but still potentially interested at using the [][] shift regsister declartion
// in a smaller module since this one goes up to 256x512 (but should pay attention to synthesis
// times to be sure)

/* synthesis analysis notes:

  This version never produced the warning "detected a potentially large (wide) shift register"
  warning and it was at 2048x16 that "[Netlist 29-201] not ideal for floor planning" began to
  to appear.

  Also, when written this way synthesis of the module began to take longer at 1024x16. The other
  shift register modules have not taken near as long to synthesis. I wonder how the [][] syntax
  has affected this? 4069 has taken no more than 10 mins...more than 50... tried to stop it, had
  to manually kill the process...

  Q: could I take the benefits from each of these designs to produce one that is replicated?
     E.g., the PE_delaybuf module that generates NUM PE_ShiftRegs never produced either warnings
     but PE_ShiftReg could only go to 64x16 before the "potentially large (wide) shift register"
     message was present. We could take the [][] here in the sr module, keep it around 256x16 or
     512x16 that synthesized faster than 1024 an subsequently instantiate less of them?
*/
module sr #(DEPTH=4096, WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

logic [WIDTH-1:0] headReg;
logic [0:DEPTH-2][WIDTH-1:0] shiftReg;

always_ff @(posedge clk)
  if (rst)
    headReg <= '0;
  else if (en)
    headReg <= din;
  else
    headReg <= headReg;

always_ff @(posedge clk)
  shiftReg <= {shiftReg[1:DEPTH-2], headReg};

always_ff @(posedge clk)
  dout <= shiftReg[0];

endmodule
