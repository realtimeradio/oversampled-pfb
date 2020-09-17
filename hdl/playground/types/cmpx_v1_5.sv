`timescale 1ns/1ps
`default_nettype none

interface axis_rfdc_v1_5 #(
  parameter WIDTH=16,
  parameter SAMP_PER_CLK=2
) (
);
  localparam samp_per_clk = SAMP_PER_CLK;
  typedef struct packed {
    logic signed [WIDTH-1:0] im;
    logic signed [WIDTH-1:0] re;
  } cx_t;

  // could make another pkt_t like `cmpx5` does, that way line 38 of the module can import the
  // type as well, or just doesn't have to use it...

  cx_t [SAMP_PER_CLK-1:0] tdata;
  logic tvalid, tready, tlast;

  modport MST (input tready, output tdata, tvalid, tlast);
  modport SLV (input tdata, tvalid, tlast, output tready);

endinterface

module impulse_generator_v1_5 #(
  parameter int FFT_LEN=16,
  parameter int IMPULSE_PHA=0,
  parameter int IMPULSE_VAL=1
) (
  input wire logic clk,
  input wire logic rst,
  axis_rfdc_v1_5.MST m_axis
);

typedef m_axis.cx_t cx_t;
localparam samp_per_clk = m_axis.samp_per_clk;
localparam mem_depth = FFT_LEN/samp_per_clk;

logic [$clog2(mem_depth)-1:0] rAddr;
cx_t [samp_per_clk-1:0] ram [mem_depth];

initial begin
  for (int i=0; i<mem_depth; i++) begin
    cx_t [samp_per_clk-1:0] pkt;
    for (int j=0; j<samp_per_clk; j++) begin
      cx_t tmp;
      tmp.re = i*samp_per_clk+ j;
      tmp.im = '0;

      pkt[j] = tmp;
    end
  ram[i] = pkt;
  end
end

always_ff @(posedge clk)
  if (rst)
    rAddr <= '0;
  else if (m_axis.tready)
    rAddr <= rAddr + 1; //+ samp_per_clk;
  else
    rAddr <= rAddr;

always_comb begin
  m_axis.tdata = { >> {ram[rAddr]}}; //+: samp_per_clk];
  //m_axis.tdata = ram[rAddr -: samp_per_clk];
  m_axis.tlast = (rAddr == (FFT_LEN-samp_per_clk)) ? 1'b1 : 1'b0;
  m_axis.tvalid = (~rst & m_axis.tready);
end
//assign m_axis.tdata = ram[rAddr +: samp_per_clk];
//assign m_axis.tvalid = (~rst & m_axis.tready);
//assign m_axis.tlast = (rAddr == (FFT_LEN-samp_per_clk)) ? 1'b1 : 1'b0;

endmodule

parameter int PERIOD = 10;

parameter int WIDTH=16;
parameter int SAMP_PER_CLK=4;

parameter int FFT_LEN = 16;
parameter int IMPULSE_PHA = 3;
parameter int IMPULSE_VAL = FFT_LEN;

module tb_v1_5();

logic clk, rst;
axis_rfdc_v1_5 #(.WIDTH(WIDTH), .SAMP_PER_CLK(SAMP_PER_CLK)) m_axis();

clk_generator #(.PERIOD(PERIOD)) clk_gen (.*);

impulse_generator_v1_5 #(
  .FFT_LEN(FFT_LEN),
  .IMPULSE_PHA(IMPULSE_PHA),
  .IMPULSE_VAL(IMPULSE_VAL)
) DUT (
  .clk(clk),
  .rst(rst),
  .m_axis(m_axis)
);

task wait_cycles(int cycles=1);
  repeat (cycles)
    @(posedge clk);
endtask

initial begin
  $display("Source ram contents");
  for (int i=0; i<FFT_LEN/SAMP_PER_CLK; i++) begin
    $display("(ram: 0x%0p", DUT.ram[i]);
  end
  $display("");

  rst <= 1; m_axis.tready <= 0;
  @(posedge clk);
  @(negedge clk); rst = 0;

  wait_cycles(20);
  @(negedge clk); m_axis.tready = 1;
  @(posedge clk);
  for (int i=0; i<2*FFT_LEN; i++) begin
    $display("(m_axis.tdata: 0x%0p)", m_axis.tdata); // could be %p or %X here as a packed type
    wait_cycles(1);
  end

  $finish;
end

endmodule
