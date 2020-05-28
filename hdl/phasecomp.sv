`timescale 1ns / 1ps
`default_nettype none

// Module: PhaseComp - Phase Compensation Buffer for the OS PFB

// A simple dual-port BRAM would be sufficient for now to implement the Ping Pong
// buffer data path. With one BRAM we therefore need to divide the total address
// space (DEPTH) of the RAM in two.

// Q: What is the best way to partition the space? Two seperate signals and add
// an offset? Or a single signal?

// For now developing with M=8, D=6 translating to the DEPTH=16 shown in the
// module parameter.

// TODO: determine the correct way in SV to use parameters correctly
//parameter int M = 8;
//parameter int D = 6;
//parameter int modinc = (M-D);

module PhaseComp #(DEPTH=16, WIDTH=16) (
  input wire logic clk,
  input wire logic rst,               // active high reset
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout

);

// TODO: do we want an idle state?
typedef enum logic {FILLA, FILLB, ERR='X} stateType;
stateType cs, ns;

logic [(WIDTH-1):0] ram[DEPTH];

logic [$clog2(DEPTH)-1:0] cs_wAddr, cs_rAddr;
logic [$clog2(DEPTH)-1:0] ns_wAddr, ns_rAddr;
logic wen, ren;   // asserted in fsm logic

// watch out will need logic to wrap the value for other shifts
// M=8, D=6 r={0,6,4,2} initial development, {0,2,4,6} correct
logic [$clog2(DEPTH/2)-1:0] shiftOffset;
logic incShift;   // asserted in fsm logic

logic [$clog2(DEPTH/2)-1:0] tmp_rAddr;

parameter int D = DEPTH;

// simple dual-port RAM inference
always_ff @(posedge clk)
  if (wen)
    ram[cs_wAddr] <= din;

always_ff @(posedge clk)
  if (ren)
    dout <= ram[cs_rAddr];

// shift offset register
always_ff @(posedge clk)
  if (rst)
    // replication needed to fill a literal with parameterizable width
    shiftOffset <= 3'd0;
  else if (incShift)
    shiftOffset <= shiftOffset-3'd2;//modinc; (M-D)=2, hard-coded for now
  else
    shiftOffset <= shiftOffset;

// write address register
// for now we will have the wAddr [0, M-1) and read address will span the
// second half of the RAM.
always_ff @(posedge clk)
  if (rst)
    cs_wAddr <= '0;
  else if (wen)
    cs_wAddr <= ns_wAddr;

// read address register
// this will be the upper half of the RAM form [M, 2M-1)
always_ff @(posedge clk)
  if (rst)
    cs_rAddr <= 4'(DEPTH)-4'b1;
  else if (ren)
    cs_rAddr <= ns_rAddr;

// FSM register
always_ff @(posedge clk)
  cs <= ns;

// Adopting the approach of using a control path and a FSM to direct the control
// path. However, since for the time being the control seems it may be straight
// forward the state machine and data path will be in the same module.

// FSM implementation
always_comb begin
  // default state values to avoid inferred latches during synthesis
  ns = ERR;
  ns_rAddr = '0;
  ns_wAddr = '0;

  incShift = 0;
  wen = 0;
  ren = 0;
  tmp_rAddr = 0;

  if (rst)
    ns = FILLA; // always start by filling A
  else
    case (cs)
      FILLA: begin
        wen = 1;
        ren = 1;
        // since we always do a write and and the the RAM is partitioned into
        // two we can just keep adding 1 and get the roll over into the right region
        ns_wAddr = cs_wAddr + 4'b1; // we can keep adding 1 as it will roll us into the upper region

        if (cs_wAddr == DEPTH/2-1) begin
          ns = FILLB;
          incShift = 1;
          tmp_rAddr = shiftOffset - 3'b1;
          ns_rAddr = tmp_rAddr;
          //ns_rAddr = shiftOffset - 3'b1; // valid reads for fillb are reads on A address space [0, 7]
          // shift is 3-bit ns_rAddr is 4-bit, a problem here? -- I really think I am being bit by this again...
          // because in filling B we are wanting to read out A's address space. But the 3-bit shiftOffset is extended
          // to 4-bit before subtraction resulting in 4'b1111 instead of 3'b111.
        end else begin
          ns = FILLA;
          if (cs_rAddr == DEPTH/2)
            ns_rAddr = 4'(DEPTH) - 4'b1;
          else
            ns_rAddr = cs_rAddr - 4'b1;
        end 
      end //FILLA

      FILLB: begin
        wen = 1;
        ren = 1;
        // since we always do a write and and the the RAM is partitioned into
        // two we can just keep adding 1 and get the roll over into the right region
        ns_wAddr = cs_wAddr + 4'b1;

        if (cs_wAddr == DEPTH-1) begin
          ns = FILLA;
          incShift = 1;
          ns_rAddr = 4'(DEPTH/2) + shiftOffset - 4'b1; // valid reads for filla are reads in B address space [8,15]
          // 4'b1 literal because DEPTH/2 is present, shift will be extended
          // from 3-bit to 4-bit.
        end else begin
          ns = FILLB;
          if (cs_rAddr == 0)
            ns_rAddr = 4'(DEPTH/2) - 4'b1;
          else
            ns_rAddr = cs_rAddr - 4'b1;
        end
      end // FILLB
    endcase // case cs
end

endmodule











