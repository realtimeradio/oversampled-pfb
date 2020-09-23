`timescale 1ns/1ps
`default_nettype none

parameter int PERIOD = 10;
parameter TWIDDLE_FILE = "../../pkgs/twiddle_n32_b23.bin";

package alpaca_butterfly_tb_pkg;

  parameter int FFT_LEN = 16;
  parameter int SAMP_PER_CLK = 2;

  parameter int WIDTH = 16;
  parameter int PHASE_WIDTH = 23;

  typedef struct packed {
    logic signed [WIDTH-1:0] im;
    logic signed [WIDTH-1:0] re;
  } cx_t;

  typedef struct packed {
    logic signed [PHASE_WIDTH-1:0] im;
    logic signed [PHASE_WIDTH-1:0] re;
  } wk_t;

  typedef struct packed { // TODO: get correct width
    logic signed [PHASE_WIDTH+WIDTH:0] im;
    logic signed [PHASE_WIDTH+WIDTH:0] re;
  } arith_t;

  typedef arith_t [SAMP_PER_CLK-1:0] arith_pkt_t;

endpackage

interface alpaca_axis #(parameter type dtype, parameter TUSER) ();

  dtype tdata;
  logic tvalid, tready;
  logic tlast;
  logic [TUSER-1:0] tuser;

  modport MST (input tready, output tdata, tvalid, tlast, tuser);
  modport SLV (input tdata, tvalid, tlast, tuser, output tready);

endinterface

/////////////////////////////////////////////////////////////////
import alpaca_butterfly_tb_pkg::*;

module alpaca_butterfly_tb();

logic clk, rst;

alpaca_axis #(.dtype(cx_t), .TUSER(8)) x1(), x2();
alpaca_axis #(.dtype(arith_pkt_t), .TUSER(16)) Xk();

clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

alpaca_butterfly #(
  .FFT_LEN(FFT_LEN),
  .WIDTH(WIDTH),
  .PHASE_WIDTH(PHASE_WIDTH),
  .TWIDDLE_FILE(TWIDDLE_FILE)
) DUT (
  .clk(clk),
  .rst(rst),
  .x1(x1),
  .x2(x2),
  .Xk(Xk)
);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

initial begin

  automatic string s1 = "{x1: %0d+j%0d, tvalid: 0b%0b, tlast: 0b%0b} {x2: %0d+j%0d, tvalid: 0b%0b, tlast: 0b%0b}";
  automatic string s2 = "{Xk[1]: %0d+j%0d}, Xk[0]: %0d+j%0d}, tvalid: 0b%0b, tlast: 0b%0b}";
  automatic string logstr = {s1, " ", s2, "\n"};
  rst <= 1;
  x1.tdata <= '0; x1.tvalid <= 0; x1.tlast <= 0; x1.tuser <= '0;
  x2.tdata <= '0; x2.tvalid <= 0; x2.tlast <= 0; x2.tuser <= '0;

  @(posedge clk);
  @(negedge clk); rst=0; x1.tvalid=1; x2.tvalid=1; x1.tuser=8'hde; x2.tuser=8'had; Xk.tready=1;

  for (int i=0; i < 20; i++) begin
    $display($psprintf(logstr, x1.tdata.re, x1.tdata.im, x1.tvalid, x1.tlast,
                          x2.tdata.re, x2.tdata.im, x2.tvalid, x2.tlast,
                          Xk.tdata[1].re, Xk.tdata[1].im,
                          Xk.tdata[0].re, Xk.tdata[0].im,
                          Xk.tvalid, Xk.tlast));
    wait_cycles(1);
    @(negedge clk);
    x1.tdata.re = x1.tdata.re+1; x1.tdata.im = x1.tdata.im+1;
    x2.tdata.re = x2.tdata.re+1; x2.tdata.im = x2.tdata.im+1;
    x2.tlast = (i%8 == 0);
  end

  $finish;
end

endmodule : alpaca_butterfly_tb


