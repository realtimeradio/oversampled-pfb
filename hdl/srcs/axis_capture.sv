`timescale 1ns/1ps
`default_nettype none

/*
  Capture AXIS Samples from upstream until RAM is full.
*/
module axis_capture #(
  parameter int WIDTH=32,
  parameter int DEPTH=65536,
  parameter int BRAM_ADDR_WID=32
) (
  input wire logic clk,
  input wire logic rst,

  axis.SLV s_axis,

  output logic [WIDTH-1:0] bram_wdata,        // Data In Bus (optional)
  output logic [WIDTH/8-1:0] bram_we,         // Byte Enables (required w/ BRAM controller)
  output logic bram_en,                       // Chip Enable Signal (optional)

  input wire logic [WIDTH-1:0] bram_rdata,    // Data Out Bus (optional)

  output logic [BRAM_ADDR_WID-1:0] bram_addr, // Address Signal (required)
  output logic bram_clk,                      // Clock Signal (required)
  output logic bram_rst,                      // Reset Signal (required)

  output logic full
);

// for simulation to testbench the logic
localparam ADDR_INC = WIDTH/8;
localparam CAP_SIZE = DEPTH*WIDTH/8;
logic signed [DEPTH*WIDTH-1:0] ram; // for simulation

logic [BRAM_ADDR_WID-1:0] wAddr;

assign bram_en = (s_axis.tready & s_axis.tvalid);
assign bram_we = {WIDTH/8{bram_en}};
assign bram_addr = wAddr;
assign bram_wdata = bram_we ? s_axis.tdata : 32'hdeadbeef; 

// passthrough for bram
assign bram_clk = clk;
assign bram_rst = rst;

always_ff @(posedge clk)
  if (rst)
    wAddr <= '0;
  else if (bram_en)
    // probably need to increment by the number of BYTES written...
    wAddr <= wAddr + ADDR_INC;
  else
    wAddr <= wAddr;

always_ff @(posedge clk)
  if (bram_en)
    ram[bram_addr*8 +: WIDTH] <= bram_wdata;

/*
   cannot accept any more writes until reset
   registered the full signal so that it will be asserted after DEPTH number of
   samples have been written, otherwise as soon as wAddr == DEPTH-1 full is asserted
   and we don't register the last value
*/
always_ff @(posedge clk)
  if (rst)
    full <= 1'b0;
  else if (wAddr >= CAP_SIZE-ADDR_INC)
    full <= 1'b1;
  else
    full <= full;

assign s_axis.tready = ~full;

endmodule

/*
  CAPTURE TESTBENCH
*/

parameter PERIOD = 10;
parameter WIDTH = 16;
parameter RAM_DEPTH = 256;
parameter BRAM_ADDR_WID = 32;

module axis_capture_tb();

logic clk, rst, full;
axis #(.WIDTH(WIDTH)) s_axis();

// bram interface signals
logic bram_clk, bram_rst, bram_en;

logic [BRAM_ADDR_WID-1:0] bram_addr;

logic [WIDTH-1:0] bram_wdata;
logic [WIDTH/8-1:0] bram_we;
logic [WIDTH-1:0] bram_rdata; // not driven

src_ctr #(
  .WIDTH(WIDTH),
  .MAX_CNT(RAM_DEPTH),
  .ORDER("natural")
) ctr (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

axis_capture #(
  .WIDTH(WIDTH),
  .DEPTH(RAM_DEPTH),
  .BRAM_ADDR_WID(BRAM_ADDR_WID)
) DUT (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis),
  .bram_wdata(bram_wdata),
  .bram_we(bram_we),
  .bram_en(bram_en),
  .bram_rdata(bram_rdata),
  .bram_addr(bram_addr),
  .bram_clk(bram_clk),
  .bram_rst(bram_rst),
  .full(full)
);

initial begin
  clk <= 0;
  forever #(PERIOD/2) clk = ~clk;
end

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

// main initial block
initial begin
  rst <= 1; bram_rdata <= 32'hdeadbeef;
  @(posedge clk);
  @(negedge clk); rst = 0;

  while (~full) begin
    wait_cycles(1);
  end

  $display("Reading out capture contents");
  for (int i=0; i < RAM_DEPTH; i++) begin
    $display("{addr: %d, data: 0x%0X}", i, DUT.ram[i*WIDTH +: WIDTH]);
  end

  $finish;
end

endmodule
