`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_dtypes_pkg::*;

/*******************************************
  Multiply, add, convergent round to even
*******************************************/

// Total latency is 7 cycles
//  mult+add = 5 cycles
//  rnd = 2 cycles (add half-lsb and pattern detect, change lsb to even if needed) 
module alpaca_multadd_convrnd (
  input wire logic clk,
  input wire logic rst,

  fp_data.I a_in,
  fp_data.I b_in,
  fp_data.I c_in,

  fp_data.O dout
);

// gather fixed point parameters to perform and check calculation widths
typedef a_in.data_t a_data_t;
typedef b_in.data_t b_data_t;
typedef c_in.data_t c_data_t;

typedef dout.data_t dout_data_t; 

localparam aw = a_in.w;
localparam af = a_in.f;

localparam bw = b_in.w;
localparam bf = b_in.f;

localparam cw = c_in.w;
localparam cf = c_in.f;

localparam doutw = dout.w;
localparam doutf = dout.f;

localparam mult_result_w = aw + bw;
localparam mult_result_f = af + bf;

localparam multadd_result_w = mult_result_w + 1; // multiplication plus one bit for the addition
localparam multadd_result_f = mult_result_f;

// temporary storage type large enough to handle growth
typedef logic signed [multadd_result_w-1:0] result_t;

initial begin
  $display("module arithmitec resultw=%0d, outw=%0d", multadd_result_w, doutw);
  $display("mult add binary point adjust: %0d", mult_result_f - cf);
end

////////////////////////////////////////////////////////////

localparam ALIGN_BP = mult_result_f - cf;
localparam MULT_LAT = 2;
localparam ADD_LAT = MULT_LAT+1;

a_data_t [MULT_LAT-1:0] a_delay;
b_data_t [MULT_LAT-1:0] b_delay;
c_data_t [ADD_LAT-1:0] c_delay;

a_data_t a;
b_data_t b;

dout_data_t rnd_out;

// intermediate registers
result_t c;           // maybe dsp??
result_t m_reg;       // internal dsp M reg
result_t multadd_reg; // internal dsp reg
result_t rnd_reg;     // maybe dsp??
logic pattern_detect;

// combinational rounding signals
localparam SHIFT_LEFT = (multadd_result_f - cf - 1);
localparam result_t half_lsb = 1'b1 << SHIFT_LEFT;

result_t mult, multadd, rnd;
logic [SHIFT_LEFT:0] pattern = '0;  // for convergent even
result_t cc = half_lsb - 1; // cc + carryin is the half-lsb of the precision we are rounding to
result_t carryin = 1'b1;

always_comb begin
  mult = a*b;
  multadd = m_reg + c;
  rnd = multadd_reg + cc + carryin;
end

always_ff @(posedge clk)
  if (rst) begin
    a_delay <= '0;
    b_delay <= '0;
    c_delay <= '0;

    a <= '0;
    b <= '0;
    c <= '0;
    m_reg <= '0;
    multadd_reg <= '0;
    rnd_reg <= '0;
    pattern_detect <= 1'b0;

  end else begin
    a_delay <= {a_delay[MULT_LAT-2:0], a_in.data};
    b_delay <= {b_delay[MULT_LAT-2:0], b_in.data};
    c_delay <= {c_delay[ADD_LAT-2:0], c_in.data};

    a <= a_delay[MULT_LAT-1];
    b <= b_delay[MULT_LAT-1];
    c <= c_delay[ADD_LAT-1] <<< ALIGN_BP; // align binary point for addition

    m_reg <= mult;
    multadd_reg <= multadd;
    pattern_detect <= rnd[SHIFT_LEFT:0] == pattern ? 1'b1 : 1'b0;
    rnd_reg <= (rnd >>> ALIGN_BP); // scale // is this shift combinational or for free?
  end

always_ff @(posedge clk)
  if (rst)
    rnd_out <= '0;
  else
    // could cause overflow if the extra overflow guard bits were used to capture the result
    rnd_out <= pattern_detect ? {rnd_reg[doutw-1:1], 1'b0} : rnd_reg[doutw-1:0];

assign dout.data = rnd_out;

endmodule : alpaca_multadd_convrnd

/****************************************************
  test synth top
****************************************************/
module alpaca_multadd_convrnd_top (
  input wire logic clk,
  input wire logic rst,
  input wire sample_t a,
  input wire coeff_t b,
  input wire sample_t c,

  output sample_t d
);

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) a_in(), c_in();
fp_data #(.dtype(coeff_t), .W(COEFF_WID), .F(COEFF_FRAC_WID)) b_in();
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) dout();

assign a_in.data = a;
assign b_in.data = b;
assign c_in.data = c;

assign d = dout.data;

alpaca_multadd_convrnd DUT (.*);

endmodule : alpaca_multadd_convrnd_top

