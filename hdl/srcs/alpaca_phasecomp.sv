`timescale 1ns / 1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

// Module: PhaseComp - Phase Compensation Buffer for the OS PFB

// out of reset the core is to process the last sample of the full first polyphase fir output.
// This can be considered as the zero-th phase. It is also the same as pulling the sample from output
// port zero of the polyphase fir into port zero of the FFT (no phase roration -- the first
// phase roation state). This is because this polyhphase first output only depends on x0 the
// rest (the previous port outputs) would have been non-causal outputs.

// Considering this, the state machine therefore comes out of the wait state, transistions to
// FILLB but only is in that state for one cycle before switching to FILLA and start from zero.

// This is implemented with a simple dual-port BRAM should be sufficient for now to implement the
// Ping Pong buffer data path. With one BRAM we therefore need to divide the total address space
// (DEPTH) of the RAM in two. One that we fill while reading out of the other.

// Note for the ospfb DEPTH=2*FFT_LEN and that for processing parallel samples the parameters
// DEPTH and DEC_FAC are presented to the core as 2*FFT_LEN/SAMP_PER_CLK and DEC_FAC/SAMP_PER_CLK
module alpaca_phasecomp #(
  parameter int DEPTH=64,
  parameter int DEC_FAC=24
) (
  input wire logic clk,
  input wire logic rst,
  alpaca_data_pkt_axis.SLV s_axis,
  alpaca_data_pkt_axis.MST m_axis
);

typedef s_axis.data_pkt_t data_pkt_t;

data_pkt_t din, dout;
logic new_sample, vld, vldd;

logic signed [$bits(data_pkt_t)-1:0] ram [DEPTH];
initial begin
  for (int i=0; i<DEPTH; i++)
    ram[i] = '0;
end

logic [$clog2(DEPTH)-1:0] cs_wAddr, cs_rAddr;
logic [$clog2(DEPTH)-1:0] ns_wAddr, ns_rAddr;
logic [$clog2(DEPTH/2)-1:0] tmp_rAddr; // to avoid a SystemVerilog gotchas to do addition correctly
logic wen, ren;

logic [$clog2(DEPTH/2)-1:0] shiftOffset;
logic incShift;

localparam int modinc = (DEPTH/2)-DEC_FAC;
localparam logic [$clog2(DEPTH/2)-1:0] shiftOffsetRstVal = '0-modinc;

// shift offset register
always_ff @(posedge clk)
  if (rst)
    shiftOffset <= shiftOffsetRstVal;
  else if (incShift)
    shiftOffset <= shiftOffset + modinc;//+/- matches python [-/+(s*D)%M] initialization
  else
    shiftOffset <= shiftOffset;

// simple dual-port RAM inference
always_ff @(posedge clk)
  if (wen)
    ram[cs_wAddr] <= din;

always_ff @(posedge clk)
  if (ren)
    dout <= ram[cs_rAddr];
  else // should probably just always enable ren and downstream know when to accept with tvalid
    dout <= '0;

// axis signals
always_ff @(posedge clk)
  if (new_sample)
    din <= s_axis.tdata;
  else
    din <= '0;

always_ff @(posedge clk) begin
  vldd <= vld;
  m_axis.tvalid <= vldd;
end

assign m_axis.tdata = dout;
assign m_axis.tlast = 1'b0;
assign m_axis.tuser = '0;

// write and read address registers
always_ff @(posedge clk)
  if (rst)
    cs_wAddr <= '1;
  else if (wen)
    cs_wAddr <= ns_wAddr;

always_ff @(posedge clk)
  if (rst)
    cs_rAddr <= (DEPTH/2) + 1;
  else if (ren)
    cs_rAddr <= ns_rAddr;

// FSM implementation
typedef enum logic [1:0] {WAIT, FILLA, FILLB, ERR='X} phasecomp_state_t;
phasecomp_state_t cs, ns;

// state register
always_ff @(posedge clk)
  cs <= ns;

// control
always_comb begin
  // default state values
  ns = ERR;
  ns_rAddr = '0;
  ns_wAddr = '0;

  incShift = 0;
  wen = 0;
  ren = 0;
  tmp_rAddr = 0;

  s_axis.tready = ~rst;
  new_sample = (s_axis.tvalid & s_axis.tready);
  vld = 0;

  // fsm cases
  if (rst)
    ns = WAIT;
  else
    case (cs)
      WAIT: begin
        if (new_sample)
          ns = FILLB;
        else
          ns = WAIT;
      end //WAIT
      FILLA: begin
        vld = 1;
        wen = 1;
        ren = 1;

        // we keep adding 1 because we will roll into the right region on state transition
        ns_wAddr = cs_wAddr + 1;

        if (cs_wAddr == (DEPTH/2)-1) begin
          ns = FILLB;
          incShift = 1;
          // valid reads for FILLB are reads on A address space [0, M-1]/samp_per_clk (lower half)
          tmp_rAddr = shiftOffset - 1;
          ns_rAddr = tmp_rAddr;
        end else begin
          ns = FILLA;
          if (cs_rAddr == DEPTH/2)
            ns_rAddr = DEPTH - 1;
          else
            ns_rAddr = cs_rAddr - 1;
        end 
      end //FILLA

      FILLB: begin
        vld = 1;
        wen = 1;
        ren = 1;

        // we keep adding 1 because we will roll into the right region on state transition
        ns_wAddr = cs_wAddr + 1;

        if (cs_wAddr == DEPTH-1) begin
          ns = FILLA;
          incShift = 1;
          // valid reads for FILLA are reads in B address space [M, 2*M-1)/samp_per_clk (upper half)
          ns_rAddr = (DEPTH/2) + shiftOffset - 1;
        end else begin
          ns = FILLB;
          if (cs_rAddr == 0)
            ns_rAddr = (DEPTH/2) - 1;

          else
            ns_rAddr = cs_rAddr - 1;
        end
      end // FILLB

      default:
        ns = ERR;
    endcase // case cs
end

endmodule : alpaca_phasecomp

