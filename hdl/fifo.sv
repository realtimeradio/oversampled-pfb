`timescale 1ns / 1ps
`default_nettype none

module fifo #(DEPTH=1024, WIDTH=16) (
  input wire logic clk,
  input wire logic rst, //active high reset
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
  //output logic wen,
  //output logic [$clog2(DEPTH-1):0] wAddr,
  //output logic ren,
  //output logic [$clog2(DEPTH-1):0] rAddr

);

typedef enum logic {WAIT, PUSHPOP, ERR='X} stateType;
stateType cs, ns;

// write and read pointers and control signals
logic [$clog2(DEPTH)-1:0] wAddr, rAddr;
logic wen, ren;

logic [(WIDTH-1):0] ram[DEPTH];

always_ff @(posedge clk)
  cs <= ns;

always_ff @(posedge clk)
  if (rst)
    wAddr <= '0;
  else if (wen) begin
    ram[wAddr] <= din;
    if (wAddr == (DEPTH-1))
      wAddr <= '0;
    else
      wAddr <= wAddr + 1;
  end

always_ff @(posedge clk)
  if (rst)
    rAddr <= '0;
  else if (ren) begin
    dout <= ram[rAddr];
    if (rAddr == (DEPTH-1))
      rAddr <= '0;
    else
      rAddr <= rAddr + 1;
  end

always_comb begin
  ns = WAIT;
  wen = 0;
  ren = 0;

  if (rst)
    ns = WAIT;
  else
    case (cs)
      WAIT: begin
        wen = 1;
        if (wAddr == (DEPTH-1))
          ns = PUSHPOP;
      end
      PUSHPOP: begin
        wen = 1;
        ren = 1;
        ns = PUSHPOP;
      end
    endcase // cs
end

endmodule
