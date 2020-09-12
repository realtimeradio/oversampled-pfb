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

typedef arith_t [SAMP_PER_CLK-1:0] cx_pkt_t;

interface alpaca_axis #(parameter type dtype, parameter TUSER) ();

  dtype tdata;
  logic tvalid, tready;
  logic tlast;
  logic [TUSER-1:0] tuser;

  modport MST (input tready, output tdata, tvalid, tlast, tuser);
  modport SLV (input tdata, tvalid, tlast, tuser, output tready);

endinterface

/////////////////////////////////////////////////////////////////

module alpaca_butterfly #(
  parameter int FFT_LEN=16,
  parameter int WIDTH=16,
  parameter int PHASE_WIDTH=23
) (
  input wire logic clk,
  input wire logic rst,
  alpaca_axis.SLV x1,
  alpaca_axis.SLV x2,

  alpaca_axis.MST Xk
  // mst tready not implemented, assuming downstream can accept
  // possible error check is to create an output put and have
  // that driven by when the mst is valid and the mst (slv) not ready
);

wk_t twiddle [FFT_LEN/2];
wk_t Wk;

arith_t WkX2, Xkhi, Xklo;

initial begin
  $readmemh("twiddle_n32_b23.bin", twiddle);
  //for (int i=0; i < FFT_LEN/2; i++) begin
  //  wk_t tmp;
  //  tmp.re = i;
  //  tmp.im = i;
  //  twiddle[i] = tmp;
  //end
end

logic [$clog2(FFT_LEN/2)-1:0] ctr;

always_ff @(posedge clk)
  if (rst)
    ctr <= '0;
  else if (x2.tvalid)
    ctr <= ctr + 1;

assign Wk = twiddle[ctr];

// The fully pipelined cmult latency is 6 cycles, right now the add is probably not right as it
// is done in the next cycle, maybe cross/boundry synthesis will optimize this into the dsp, and
// but so we may need to add more for better fclk. Also may want to add more to clock the
// twiddle factor out.
// cmult latency + final add/sub (may need more, see above note)
localparam AXIS_LAT = 7;
localparam X1_LAT = AXIS_LAT-1;
logic [1:0] axis_delay [AXIS_LAT-1:0]; // {tvalid, tlast}
// not sure if this is the best way to get the user width here...
logic [$bits(Xk.tuser)-1:0] axis_tuser_delay [AXIS_LAT-1:0]; // concatenate x1/x2 tuser as {x1,x2}

// opting for x2 last/valid propagation
always_ff @(posedge clk) begin
  axis_delay <= {axis_delay[AXIS_LAT-2:0], {x2.tvalid, x2.tlast}};
  axis_tuser_delay <= {axis_tuser_delay[AXIS_LAT-2:0] , {x1.tuser, x2.tuser}};
end

cx_t [X1_LAT-1:0] x1_delay;

always_ff @(posedge clk)
  x1_delay <= {x1_delay[X1_LAT-2:0], x1.tdata};

assign Xk.tvalid = axis_delay[AXIS_LAT-1][1];
assign Xk.tlast = axis_delay[AXIS_LAT-1][0];
assign Xk.tuser = axis_tuser_delay[AXIS_LAT-1];

assign x1.tready = ~rst;
assign x2.tready = ~rst;

cmult #(
  .AWIDTH(WIDTH),
  .BWIDTH(PHASE_WIDTH)
) DUT (
  .clk(clk),
  .ar(x2.tdata.re),
  .ai(x2.tdata.im),
  .br(Wk.re),
  .bi(Wk.im),
  .pr(WkX2.re),
  .pi(WkX2.im)
);

// the delay is showing computation one cycle later in simulation but may need
// to do another one for dsp slice clock efficiency?
always_ff @(posedge clk) begin
  Xkhi.re <= x1_delay[X1_LAT-1].re - WkX2.re;
  Xkhi.im <= x1_delay[X1_LAT-1].im - WkX2.im;
  Xklo.re <= x1_delay[X1_LAT-1].re + WkX2.re;
  Xklo.im <= x1_delay[X1_LAT-1].im + WkX2.im;
end

assign Xk.tdata = {Xkhi, Xklo};

endmodule : alpaca_butterfly

module cmpx_tb();

logic clk, rst;

alpaca_axis #(.dtype(cx_t), .TUSER(8)) x1(), x2();
alpaca_axis #(.dtype(cx_pkt_t), .TUSER(16)) Xk();

clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

alpaca_butterfly #(
  .FFT_LEN(FFT_LEN),
  .WIDTH(WIDTH),
  .PHASE_WIDTH(PHASE_WIDTH)
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

endmodule : cmpx_tb

/*******************
  testing cmult
*****************/

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
