`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

module alpaca_butterfly #(
  parameter int FFT_LEN=16,
  //parameter int WIDTH=16,
  //parameter int PHASE_WIDTH=23,
  parameter TWIDDLE_FILE=""
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

// could not simply do 'wk_t twiddle [FFT_LEN/2]`
// Vivado synthesis would warn that the readmemh task was malformed and that 'twiddle' was an
// 'invalid memory name'. Therefore in the context of memory Vivado cannot recognize that a
// packed struct is just a vector of bits. Adding the $bits() call was enough to help vivado
// out... this is a bug... no reason vivado shouldn't be able to understand this.
logic [$bits(wk_t)-1:0] twiddle [FFT_LEN/2];
wk_t Wk;

arith_t WkX2, Xkhi, Xklo;

localparam phase_width = $bits(Wk.re);
// I hate this because it is not descriptive or obvious that alpaca_axis tdata is really a cx_t
// object. I like not having to pass the width through all the parameters but is that worth it?
localparam width = $bits(x2.tdata)/2;

initial begin
  $readmemh(TWIDDLE_FILE, twiddle);
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
logic [AXIS_LAT-1:0][1:0] axis_delay; // {tvalid, tlast}
// not sure if this is the best way to get the user width here...
logic [AXIS_LAT-1:0][$bits(Xk.tuser)-1:0] axis_tuser_delay; // concatenate x1/x2 tuser as {x1,x2}

// opting for x2 last/valid propagation
always_ff @(posedge clk) begin
  axis_delay <= {axis_delay[AXIS_LAT-2:0], {x2.tvalid, x2.tlast}};
  axis_tuser_delay <= {axis_tuser_delay[AXIS_LAT-2:0] , {x1.tuser, x2.tuser}};
end

// vivado synthesis comes back and says that this will most likely be implemented in registers
// because the abstract data type recognition is not supported. Registers are what I want and
// this is OK. But were I to change to `logic signed [X1_LAT-1:0][$bits(cx_t)-1:0] x1_delay;` I
// would then not be able to pull out the real and imaginary part with .re/.im struct notation.
cx_t [X1_LAT-1:0] x1_delay;

always_ff @(posedge clk)
  x1_delay <= {x1_delay[X1_LAT-2:0], x1.tdata};

assign Xk.tvalid = axis_delay[AXIS_LAT-1][1];
assign Xk.tlast = axis_delay[AXIS_LAT-1][0];
assign Xk.tuser = axis_tuser_delay[AXIS_LAT-1];

assign x1.tready = ~rst;
assign x2.tready = ~rst;

cmult #(
  .AWIDTH(width),
  .BWIDTH(phase_width)
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