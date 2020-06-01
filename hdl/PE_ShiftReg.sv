`timescale 1ns/1ps
`default_nettype none

// synthesis notes: getting the synthesis warning
// able to infer SRL32s here.
// increasing depth by powers of 2 I get the following warnings at 1024
//
// WARNING: [Netlist 29-101] Netlist 'PE_ShiftReg' is not ideal for floorplanning, since the cellview 'PE_ShiftReg' contains a large number
// of primitives.  Please consider enabling hierarchy in synthesis if you want to do floorplanning.
//
// this concerns me that place and route and/or timing will be difficult with this warning and am trying to dunderstand the "hierarchy"
// information mentioned. This should be the "flatten hierarchy" switch. I found you can send that in non-project mode with the synth_design
// command. Pasing all of the options for 4096 the same warning results.
//
// The thought crossed my mind that this module has several signals that we learned in 620 we could live without if we were able to live
// with some tradeoffs. Here, we are getting SRL32s and they are built of LUTs. The warning here could be from the fact that each of these
// have an en and a rst. Which we learned could have large wiring and net requirement. Therefore, I want to investigate removing the enable
// and reset signals or do a loadable beginning register that then propagates the value through

module PE_ShiftReg #(DEPTH=4096, WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

logic [DEPTH*WIDTH-1:0] shiftReg;
logic [WIDTH-1:0] tmp_dout;

always_ff @(posedge clk)
  if (rst)
    shiftReg <= '0;
  else if (en)
    shiftReg <= {shiftReg[(DEPTH-1)*WIDTH:0], din};
  else
    shiftReg <= shiftReg;

always_ff @(posedge clk)
  if (rst)
    tmp_dout <= '0;
  else if (en)
    tmp_dout <= shiftReg[DEPTH*WIDTH-1:(DEPTH-1)*WIDTH];
    //dout <= shiftReg[DEPTH*WIDTH-1:(DEPTH-1)*WIDTH];
  else
    tmp_dout <= tmp_dout;
    //dout <= tmp_dout;

assign dout = tmp_dout;

endmodule
