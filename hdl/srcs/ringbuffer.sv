`timescale 1ns/1ps
`default_nettype none

module ringbuffer #(
  parameter int WIDTH=16,
  parameter int DEPTH=4
) (
  input wire logic clk,
  input wire logic rst,
  axis.SLV s_axis,
  axis.MST m_axis
);

logic [WIDTH-1:0] fifo [DEPTH];
logic [$clog2(DEPTH)-1:0] cs_rAddr, cs_wAddr, ns_rAddr, ns_wAddr;

logic ren, wen, full, empty;

assign ren = m_axis.tready;
assign wen = (s_axis.tready & s_axis.tvalid);

always_ff @(posedge clk)
  if (wen)
    fifo[cs_wAddr] <= s_axis.tdata;

//always_ff @(posedge clk)
//  if (ren)
//    m_axis.tdata <= fifo[cs_rAddr];
assign m_axis.tdata = fifo[cs_rAddr];

always_ff @(posedge clk)
  if (rst)
    cs_wAddr <= '0;
  else
    cs_wAddr <= ns_wAddr;

always_ff @(posedge clk)
  if (rst)
    cs_rAddr <= '0;
  else
    cs_rAddr <= ns_rAddr;

typedef enum logic [1:0] {EMPTY, FILL, FULL, ERR='X} fifo_state;
fifo_state cs, ns;

always_ff @(posedge clk)
  cs <= ns;

always_comb begin
  //default values
  ns = ERR;
  ns_rAddr = '0;
  ns_wAddr = '0;
  empty = 1'b0;
  full = 1'b0;

  if (rst)
    ns = EMPTY;
  else
    case (cs)
      EMPTY: begin
        if (wen)
          ns = FILL;
          ns_wAddr = cs_wAddr + 1;
          empty = 1'b1;
        end else begin
          ns = FILL;
        end
      end

      FILL: begin
        if (wen & ren) begin
          ns = FILL;
          ns_wAddr = cs_wAddr + 1;
          ns_rAddr = ns_rAddr + 1;
        end else if (wen) begin
          ns_wAddr = cs_wAddr + 1;
          if (ns_wAddr == cs_rAddr)
            ns = FULL;
        end else if (ren) begin
          ns_rAddr = ns_rAddr + 1;
          if (ns_rAddr == cs_wAddr)
            ns = EMPTY;
        end else
            ns = FILL;
      end

      FULL: begin
        if (ren) begin
          ns = FILL;
          ns_rAddr = cs_rAddr + 1;
        end
      end

    endcase

end

endmodule
