`timescale 1ns/1ps
`default_nettype none


// moved to attic because of following notes... mainly it didn't seem that an alpaca sized
// delay line coded this way to infer a srl32 was not very smart synthesis wise and would only get
// messier later on. Also, wasn't verified and didn't seem like an easy way to probe internal signals
// because there was no way to use the `bind` construct on a probe interface and access each of
// the'generate' blocks shiftregs with out having to hard code the constants in.
//

// synthesis notes:

// this one is still not verified correctly functional however the number SRL32s match the
// versions that are working and so at least the same amount of hardware is present.

// however starting at 2048 (NUMxDEPTH=32*64) the warning "[Netlist 29-101] not ideal for
// floorplanning" occurs. This points to doing a small shift register module and instantiating
// that as it seems to be the best suit for synthesis. Also, the partitions, and mappings are all
// over the place (not as clean as doing a smaller module) leaving me to believe the synthesis
// tool tries to do a lot of guess work at optimizaing that could potentially hurt us come
// implementation

module GenShiftReg #(NUM=64, DEPTH=64, WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

logic [WIDTH-1:0] headReg;

always_ff @(posedge clk)
  if (rst)
    headReg <= '0;
  else if (en)
    headReg <= din;
  else
    headReg <= headReg;

genvar i;
logic [NUM-1:0][WIDTH-1:0] tmpout;
generate
  for (i=0; i<NUM; i++) begin : generate_delayline

    logic [(DEPTH-1)*WIDTH-1:0] shiftReg;
    if (i==0) begin 

      always_ff @(posedge clk)
        shiftReg <= {shiftReg[(DEPTH-2)*WIDTH:0], headReg}; 

    end
    else begin
      always_ff @(posedge clk)
        shiftReg <= {shiftReg[(DEPTH-2)*WIDTH:0], tmpout[i-1]};
    end

    always_ff @(posedge clk)
      tmpout[i] <= shiftReg[(DEPTH-1)*WIDTH-1:(DEPTH-2)*WIDTH];

    if (i==NUM-1) begin
      assign dout = tmpout[i];
    end
  end
endgenerate

endmodule
