`timescale 1ns / 1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

// Module: PhaseComp - Phase Compensation Buffer for the OS PFB

// A simple dual-port BRAM would be sufficient for now to implement the Ping Pong
// buffer data path. With one BRAM we therefore need to divide the total address
// space (DEPTH) of the RAM in two.

//TODO: Evaluate the folllwing...
// Possibility to redo the phase rotation buffer using two ram variables instead of the one
//  A) this may reduce FSM complexity (although not very complex now)
//  B) may be more efficient for how the tool can cascade deep rams for address resolution
//  C) apply output pipelined regiters in this behavioral description

// note for the ospfb DEPTH=2*FFT_LEN
module PhaseComp #(
  parameter int DEPTH=64,
  parameter int DEC_FAC=24,
  parameter int SAMP_PER_CLK=2
) (
  input wire logic clk,
  input wire logic rst,
  input wire fir_pkt_t din,
  output fir_pkt_t dout
);

typedef enum logic {FILLA, FILLB, ERR='X} phasecomp_state_t;
phasecomp_state_t cs, ns;

logic signed [$bits(fir_pkt_t)-1:0] ram [DEPTH];

logic [$clog2(DEPTH)-1:0] cs_wAddr, cs_rAddr;
logic [$clog2(DEPTH)-1:0] ns_wAddr, ns_rAddr;
logic wen, ren;   // asserted in fsm logic

logic [$clog2(DEPTH/2)-1:0] shiftOffset;
logic incShift;   // asserted in fsm logic

logic [$clog2(DEPTH/2)-1:0] tmp_rAddr;

// why does the width call to $clog not subtract one?
localparam logic [$clog2(DEPTH/2):0] modinc = (DEPTH/2)-(DEC_FAC/SAMP_PER_CLK); // this is really (M-D)/samp_per_clk

// initialize contents to zero
initial begin
  for (int i=0; i<DEPTH; i++)
    ram[i] = '0;
end

// simple dual-port RAM inference
always_ff @(posedge clk)
  if (wen)
    ram[cs_wAddr] <= din;

// Synchronous vs. Asynchronous reads - the asynchronous read lines up with the
// test data but may have a poor impact on timing. Synchronous would improve timing
// but require we add these pipeline registers everywhere (i.e., SRL delaybuf modules)
//always_ff @(posedge clk)
//  if (ren)
//    dout <= ram[cs_rAddr];
assign dout = ram[cs_rAddr];

// shift offset register
always_ff @(posedge clk)
  if (rst)
    //shiftOffset <= '0;
    shiftOffset <= '0-modinc; // TODO: make this a better representation for synthesis...
  else if (incShift)
    shiftOffset <= shiftOffset + modinc; //+ matches python [-(s*D)%M] initialization
    //shiftOffset <= shiftOffset - modinc; //- matches python [(s*D)%M] initialization
  else
    shiftOffset <= shiftOffset;

// write address register
// for now we will have the wAddr [0, M-1) and read address will span the
// second half of the RAM.
always_ff @(posedge clk)
  if (rst)
    //cs_wAddr <= '0;
    cs_wAddr <= '1;
  else if (wen)
    cs_wAddr <= ns_wAddr;

// read address register
// this will be the upper half of the RAM form [M, 2M-1)
always_ff @(posedge clk)
  if (rst)
    // NOTE: the other three changes
    // 1.) shiftOffset M <= '0-modinc 2.) cs_wAddr <= '0 and 3.) ns = FILLA
    // are all required to work correctly, however this change is not and yields
    // correct answers. However, to be exact it seemed to make sense make it match up
    //cs_rAddr <= '1;
    cs_rAddr <= (DEPTH/2) + 1;
  else if (ren)
    cs_rAddr <= ns_rAddr;

// FSM register
always_ff @(posedge clk)
  cs <= ns;

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

  // fsm cases
  if (rst)
    //ns = FILLA; // always start by filling A
    ns = FILLB;
  else
    case (cs)
      FILLA: begin
        wen = 1;
        ren = 1;
        // since we always do a write and and the the RAM is partitioned into
        // two we can just keep adding 1 and get the roll over into the right region
        ns_wAddr = cs_wAddr + 1;

        if (cs_wAddr == (DEPTH/2)-1) begin
          ns = FILLB;
          incShift = 1;
          // valid reads for fillb are reads on A address space (lower half)
          tmp_rAddr = shiftOffset - 1;
          ns_rAddr = tmp_rAddr;
          //ns_rAddr = shiftOffset - 3'b1;
        end else begin
          ns = FILLA;
          if (cs_rAddr == DEPTH/2)
            ns_rAddr = DEPTH - 1;
          else
            ns_rAddr = cs_rAddr - 1;
        end 
      end //FILLA

      FILLB: begin
        wen = 1;
        ren = 1;
        // since we always do a write and and the the RAM is partitioned into
        // two we can just keep adding 1 and get the roll over into the right region
        ns_wAddr = cs_wAddr + 1;

        if (cs_wAddr == DEPTH-1) begin
          ns = FILLA;
          incShift = 1;
          // valid reads for filla are reads in B address space [8,15] (upper half)
          // we don't have the same losely typed roll over issue here because the upper
          // address space goes from 3 to 4 bits
          ns_rAddr = (DEPTH/2) + shiftOffset - 1;
        end else begin
          ns = FILLB;
          if (cs_rAddr == 0)
            ns_rAddr = (DEPTH/2) - 1;

          else
            ns_rAddr = cs_rAddr - 1;
        end
      end // FILLB
    endcase // case cs
end

endmodule : PhaseComp


