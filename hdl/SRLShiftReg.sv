`timescale 1ns/1ps
`default_nettype none


// TODO: Note to document that without an enable anytime we get a hiccup we will have to 'reset'
// the circuit to flush values for the depth of the SRs

// TODO: Does this need to have a parameterized data type?

module SRLShiftReg #(parameter DEPTH=8, parameter WIDTH=16) (
  input wire logic clk,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

logic [DEPTH*WIDTH-1:0] shiftReg;

always_ff @(posedge clk)
  shiftReg <= {shiftReg[(DEPTH-1)*WIDTH-1:0], din};

assign dout = shiftReg[DEPTH*WIDTH-1:(DEPTH-1)*WIDTH];

// This registers the output - which we don't want when chaining modules.
//always_ff @(posedge clk)
//  dout <= shiftReg[DEPTH*WIDTH-1:(DEPTH-1)*WIDTH];

endmodule

module DelayBuf #(
  parameter DEPTH=16,
  parameter SRLEN=16,
  parameter WIDTH=16,
  parameter NUM=(DEPTH/SRLEN) - 1)
(
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

// is possible to move this to MAC so that the DSP has an output register for timing
// because in synthesis i am not sure if it will be able to notice that headReg is
// a register next to it an input especially if we are slicing. Trying to say we could
// use the slice as one of the clocks of the many in our delayline.
logic [WIDTH-1:0] headReg;

always_ff @(posedge clk)
  if (rst)
    headReg <= '0;
  else if (en)
    headReg <= din;
  else
    headReg <= headReg;

logic [WIDTH-1:0] headSROut;
SRLShiftReg #(
  .DEPTH(SRLEN-1),
  .WIDTH(WIDTH)
) headSR (
  .clk(clk),
  .din(headReg),
  .dout(headSROut)
);

generate
  if (NUM < 1) begin : gen_delay
    assign dout = headSROut;

  end else if (NUM < 2) begin : gen_delay
    logic [WIDTH-1:0] tmpout;
    SRLShiftReg #(
      .DEPTH(SRLEN),
      .WIDTH(WIDTH)
    ) sr (
      .clk(clk),
      .din(headSROut),
      .dout(tmpout)
    );

    assign dout = tmpout;

  end else begin : gen_delay
    logic [0:NUM-1][WIDTH-1:0] tmpout;
    SRLShiftReg #(
      .DEPTH(SRLEN),
      .WIDTH(WIDTH)
    ) sr[0:NUM-1] (
      .clk(clk),
      .din({headSROut, tmpout[0:NUM-2]}),
      .dout(tmpout)
    );

    assign dout = tmpout[NUM-1];

  end
endgenerate


endmodule










