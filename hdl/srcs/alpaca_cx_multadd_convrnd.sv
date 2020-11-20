`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/*******************************************************************
  Multiply add for parallel fft twiddle factor recombination

  perform a complex multiplication followed by an addition and subtraction
  add_dout = A*B + C
  sub_dout = A*B - C
  A,B and C are complex numbers
********************************************************************/

module alpaca_cx_multadd_convrnd (
  input wire logic clk,
  input wire logic rst,

  fp_data.I ar_in, ai_in,
  fp_data.I br_in, bi_in,
  fp_data.I cr_in, ci_in,

  fp_data.O add_dout_re, add_dout_im,
  fp_data.O sub_dout_re, sub_dout_im
);

// use fixed-point parameters to create types and check computation widths
typedef ar_in.data_t a_data_t;
typedef br_in.data_t b_data_t;
typedef cr_in.data_t c_data_t;

typedef add_dout_re.data_t dout_data_t;

localparam aw = ar_in.w;
localparam af = ar_in.f;

localparam bw = br_in.w;
localparam bf = br_in.f;

localparam cw = cr_in.w;
localparam cf = cr_in.f;

localparam doutw = add_dout_re.w;
localparam doutf = add_dout_re.f;

localparam mult_result_w = aw + bw;
localparam mult_result_f = af + bf;

localparam multadd_result_w = mult_result_w + 1; // multiplication plus one bit for the addition
localparam multadd_result_f = mult_result_f;

// temporary storage type large enough to handle growth
typedef logic signed [multadd_result_w-1:0] result_t;

// display widths
initial begin
  $display("cx module arithmetic res=%0d, outw=%0d", multadd_result_w, doutw);
  $display("cx mult binary point adjust: %0d", mult_result_f - cf);
end
///////////////////////////////////

localparam ALIGN_BP = mult_result_f - cf;

// nominally a latency of 4 is required on the A pipeline but an additional one has been added
// for clocking in a twiddle factor coefficient
// Fully pipelined latency: input form bram = 1, cx mult=6, twiddle add/sub = 1, rnd=2
localparam A_LAT = 5;
localparam B_LAT = A_LAT-1;
localparam C_LAT = A_LAT+1;

a_data_t [A_LAT-1:0] ar_delay, ai_delay;
b_data_t [B_LAT-1:0] br_delay, bi_delay;
c_data_t [C_LAT-1:0] cr_delay, ci_delay;

logic signed [bw:0] add_re, add_im;
logic signed [aw:0] addcommon;

dout_data_t rndadd_out_re, rndadd_out_im;
dout_data_t rndsub_out_re, rndsub_out_im;

// intermediate registers
result_t m_reg_common, m_reg_common_d;
result_t common_im, common_re;
result_t m_reg_re, m_reg_im;  // register intermediate multiplication output

result_t c_re, c_im; // for scaled c input

result_t cxmult_re, cxmult_im;
result_t multadd_re, multadd_im;
result_t multsub_re, multsub_im;

result_t rndadd_re_reg, rndadd_im_reg;
result_t rndsub_re_reg, rndsub_im_reg;

logic pd_add_re, pd_add_im; // pattern detect registers
logic pd_sub_re, pd_sub_im;

// combinational rounding signals
localparam SHIFT_LEFT = (multadd_result_f - cf - 1);
localparam result_t half_lsb = 1'b1 << SHIFT_LEFT;

result_t rndadd_re, rndadd_im;
result_t rndsub_re, rndsub_im;
logic [SHIFT_LEFT:0] pattern = '0; // for convergent even
result_t cc = half_lsb - 1;
result_t carryin = 1'b1;

// arithmetic computations
always_comb begin
  rndadd_re = multadd_re + cc + carryin;
  rndadd_im = multadd_im + cc + carryin;
  rndsub_re = multsub_re + cc + carryin;
  rndsub_im = multsub_im + cc + carryin;
end

// generate common factor for 3 dsp slice implementation
always_ff @(posedge clk) begin
  if (rst) begin
    addcommon <= '0;
    m_reg_common <= '0;
    m_reg_common_d <= '0;
  end else begin
    addcommon <= ar_delay[A_LAT-4] - ai_delay[A_LAT-4];

    m_reg_common <= addcommon * bi_delay[B_LAT-2];
    m_reg_common_d <= m_reg_common;
  end
end

// real products
always_ff @(posedge clk) begin
  if (rst) begin
    ar_delay <= '0; br_delay <= '0; cr_delay <= '0;
    add_re <= '0;
    m_reg_re <= '0;
    common_re <= '0;
    cxmult_re <= '0;
    c_re <= '0;
    multadd_re <= '0;
    multsub_re <= '0;
    pd_add_re <= 1'b0;
    pd_sub_re <= 1'b0;
    rndadd_re_reg <= '0;
    rndsub_re_reg <= '0;
  end else begin
    ar_delay <= {ar_delay[A_LAT-2:0], ar_in.data};
    br_delay <= {br_delay[B_LAT-2:0], br_in.data};
    cr_delay <= {cr_delay[C_LAT-2:0], cr_in.data};

    add_re <= br_delay[B_LAT-1] - bi_delay[B_LAT-1];

    m_reg_re <= ar_delay[A_LAT-1]*add_re;
    common_re <= m_reg_common_d;

    cxmult_re <= m_reg_re + common_re;
    c_re <= (cr_delay[C_LAT-1] <<< ALIGN_BP); // align binary point for addition

    multadd_re <= c_re + cxmult_re;
    multsub_re <= c_re - cxmult_re;

    pd_add_re <= rndadd_re[SHIFT_LEFT:0] == pattern ? 1'b1 : 1'b0;
    pd_sub_re <= rndsub_re[SHIFT_LEFT:0] == pattern ? 1'b1 : 1'b0;
    rndadd_re_reg <= (rndadd_re >>> ALIGN_BP);
    rndsub_re_reg <= (rndsub_re >>> ALIGN_BP);
  end
end

// imaginary products
always_ff @(posedge clk) begin
  if (rst) begin
    ai_delay <= '0; bi_delay <= '0; ci_delay <= '0;
    add_im <= '0;
    m_reg_im <= '0;
    common_im <= '0;
    cxmult_im <= '0;
    c_im <= '0;
    multadd_im <= '0;
    multsub_im <= '0;
    pd_add_im <= 1'b0;
    pd_sub_im <= 1'b0;
    rndadd_im_reg <= '0;
    rndsub_im_reg <= '0;
  end else begin
    ai_delay <= {ai_delay[A_LAT-2:0], ai_in.data};
    bi_delay <= {bi_delay[B_LAT-2:0], bi_in.data};
    ci_delay <= {ci_delay[C_LAT-2:0], ci_in.data};

    add_im <= br_delay[B_LAT-1] + bi_delay[B_LAT-1];

    m_reg_im <= ai_delay[A_LAT-1]*add_im;
    common_im <= m_reg_common_d;

    cxmult_im <= m_reg_im + common_im;
    c_im <= (ci_delay[C_LAT-1] <<< ALIGN_BP); // align binary point for addition

    multadd_im <= c_im + cxmult_im;
    multsub_im <= c_im - cxmult_im;

    pd_add_im <= rndadd_im[SHIFT_LEFT:0] == pattern ? 1'b1 : 1'b0;
    pd_sub_im <= rndsub_im[SHIFT_LEFT:0] == pattern ? 1'b1 : 1'b0;
    rndadd_im_reg <= (rndadd_im >>> ALIGN_BP);
    rndsub_im_reg <= (rndsub_im >>> ALIGN_BP);
  end
end

always_ff @(posedge clk) begin
  if (rst) begin
    rndadd_out_re <= '0;
    rndadd_out_im <= '0;
    rndsub_out_re <= '0;
    rndsub_out_im <= '0;
  end else begin 
    // could cause overflow if the extra overflow guard bits were used to capture the result
    rndadd_out_re <= pd_add_re ? {rndadd_re_reg[doutw-1:1], 1'b0} : rndadd_re_reg[doutw-1:0];
    rndadd_out_im <= pd_add_im ? {rndadd_im_reg[doutw-1:1], 1'b0} : rndadd_im_reg[doutw-1:0];
    rndsub_out_re <= pd_sub_re ? {rndsub_re_reg[doutw-1:1], 1'b0} : rndsub_re_reg[doutw-1:0];
    rndsub_out_im <= pd_sub_im ? {rndsub_im_reg[doutw-1:1], 1'b0} : rndsub_im_reg[doutw-1:0];
  end
end

assign add_dout_re.data = rndadd_out_re;
assign add_dout_im.data = rndadd_out_im;
assign sub_dout_re.data = rndsub_out_re;
assign sub_dout_im.data = rndsub_out_im;


endmodule : alpaca_cx_multadd_convrnd

/****************************************************
  test synth top
****************************************************/
import alpaca_constants_pkg::*;

module alpaca_cx_multadd_convrnd_top (
  input wire logic clk,
  input wire logic rst,
  input wire sample_t ar, ai,
  input wire phase_t br, bi,
  input wire sample_t cr, ci,

  output sample_t add_re, add_im,
  output sample_t sub_re, sub_im
);

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) ar_in(), ai_in(), cr_in(), ci_in();
fp_data #(.dtype(phase_t), .W(PHASE_WIDTH), .F(PHASE_FRAC_WIDTH)) br_in(), bi_in();
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) add_dout_re(), add_dout_im();
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) sub_dout_re(), sub_dout_im();

assign ar_in.data = ar;
assign ai_in.data = ai;
assign br_in.data = br;
assign bi_in.data = bi;
assign cr_in.data = cr;
assign ci_in.data = ci;

assign add_re = add_dout_re.data;
assign add_im = add_dout_im.data;
assign sub_re = sub_dout_re.data;
assign sub_im = sub_dout_im.data;

alpaca_cx_multadd_convrnd DUT (.*);

endmodule : alpaca_cx_multadd_convrnd_top

