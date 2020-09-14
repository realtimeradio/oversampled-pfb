`timescale 1ns/1ps
`default_nettype none

parameter int PERIOD = 10;
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

/////////////////////////////////////////////////////////////////

module cmult_tb();

logic clk;

cx_t x;
wk_t twiddle;

arith_t out;

clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

cmult #(
  .AWIDTH(WIDTH),
  .BWIDTH(PHASE_WIDTH)
) DUT (
  .clk(clk),
  .ar(x.re),
  .ai(x.im),
  .br(twiddle.re),
  .bi(twiddle.im),
  .pr(out.re),
  .pi(out.im)
);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

initial begin
  x <= '0; twiddle <= '0;
  @(posedge clk);
  @(negedge clk);// x.re = 16'sd2; x.im = 16'sd4; twiddle.re = 23'sd5; twiddle.im = 23'sd3;

  for (int i=0; i < 20; i++) begin
    $display("x:(re: %0d, im: %0d), t:(re: %0d, im: %0d), out: (re: %0d, im: %0d)",
      x.re, x.im, twiddle.re, twiddle.im, out.re, out.im);
    wait_cycles(1);
    @(negedge clk);
    x.re += 1; x.im +=1; twiddle.re += 1; twiddle.im += 1;
  end

  $finish;
end

endmodule : cmult_tb
