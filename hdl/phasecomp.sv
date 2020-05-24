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
logic wen, ren;   // needs fsm logic

logic incShift;   // needs fsm logic
logic [(DEPTH/2)-1:0] shiftOffset; // watch out will need logic to wrap it

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
    shiftOffset <= shiftOffset-2;//modinc; (M-D)=2 minus for correct, plus was initial development
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
    cs_rAddr <= (DEPTH/2);
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

  if (rst)
    ns = FILLA; // always start by filling A
  else
    case (cs)
      FILLA: begin
        wen = 1;
        ren = 1;

        if (cs_wAddr == DEPTH/2-1) begin
          ns = FILLB;
          incShift = 1;
          ns_wAddr = cs_wAddr + 1; // we can keep adding 1 as it will roll us into the upper region
          ns_rAddr = DEPTH/2 + shiftOffset - 1;
        end else begin
          ns = FILLA;
          ns_wAddr = cs_wAddr + 1;
          if (cs_rAddr == DEPTH/2)
            ns_rAddr = DEPTH-1;
          else
            ns_rAddr = cs_rAddr-1;
        end 
      end //FILLA

      FILLB: begin
        wen = 1;
        ren = 1;

        if (cs_wAddr == DEPTH-1) begin
          ns = FILLA;
          incShift = 1;
          ns_wAddr = cs_wAddr + 1;
          ns_rAddr = shiftOffset - 1;
        end else begin
          ns = FILLB;
          ns_wAddr = cs_wAddr + 1;
          if (cs_rAddr == 0)
            ns_rAddr = DEPTH/2-1;
          else
            ns_rAddr = cs_rAddr - 1;
        end
      end // FILLB
    endcase // case cs
end

endmodule











