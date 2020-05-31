`timescale 1ns / 1ps
`default_nettype none

// Module: PhaseComp - Phase Compensation Buffer for the OS PFB

// A simple dual-port BRAM would be sufficient for now to implement the Ping Pong
// buffer data path. With one BRAM we therefore need to divide the total address
// space (DEPTH) of the RAM in two.

// For now developing with M=8, D=6 translating to the DEPTH=16 shown in the
// module parameter.

//parameter int FFT_LEN = 8;
//parameter int DEC_FAC = 6;

//TODO: Next steps...
// 1. move parameters for synthesizable parameters to module parameter declaration list
// 2. investigate templating types to send real data through ports for verification
// 3. work on a PE implementation using a shift register behavioral description to see if we can get SRL32s instantiated
// 4. Possibility to redo the phase rotation buffer using two ram variables instead of the one
//  A) this may reduce FSM complexity (although not very complex now)
//  B) may be more efficient for how the tool can cascade deep rams for address resolution
//  C) apply output pipelined regiters in this behavioral description
//  D) work on a version that instatiates a BRAM instead of infers one
// 5. Get some of the TB classes into the ospfb package

module PhaseComp #(DEPTH=16, WIDTH=16, DEC_RATE=6) (//, parameter logic [$clog2(DEPTH/2):0] modinc = DEPTH/2-DEC_RATE) (
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

logic [$clog2(DEPTH/2)-1:0] shiftOffset;
logic incShift;   // asserted in fsm logic

logic [$clog2(DEPTH/2)-1:0] tmp_rAddr;

parameter logic [$clog2(DEPTH/2):0] modinc = DEPTH/2-DEC_RATE;

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
    shiftOffset <= '0;
  else if (incShift)
    shiftOffset <= shiftOffset - modinc;// {{($clog2(DEPTH/2)-$clog2(2)){1'b0}}, {$clog2(2){2'b10}}};
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
    // replication needed to fill a literal with parameterizable width
    cs_rAddr <= '1;
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
        ns_wAddr = cs_wAddr + 1;

        if (cs_wAddr == DEPTH/2-1) begin
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
            ns_rAddr = DEPTH/2 - 1;

          else
            ns_rAddr = cs_rAddr - 1;
        end
      end // FILLB
    endcase // case cs
end

endmodule











