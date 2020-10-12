`timescale 1ns/1ps
`default_nettype none

import cx_types_pkg::*;

/*******************************************************************
  Multiply add

  perform a complex multiplication followed by an addition
  dout = A*B + C
  Where A,B and C are complex numbers
********************************************************************/

module alpaca_cx_multadd (
  input wire logic clk,
  input wire logic rst,
  fp_data.I ar_in, ai_in,
  fp_data.I br_in, bi_in,
  fp_data.I cr_in, ci_in,

  fp_data.O add_dout_re, add_dout_im,
  fp_data.O sub_dout_re, sub_dout_im
);

// gather fixed point parameters to perform and check calculation widths
typedef ar_in.data_t a_data_t;
typedef br_in.data_t b_data_t;
typedef cr_in.data_t c_data_t;

typedef add_dout_re.data_t result_t; 

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

// check widths of input interfaces
initial begin
  assert (multadd_result_w== doutw) begin
    $display("module arithmitec res=%0d, outw=%0d", multadd_result_w, doutw);
    $display("binary point adjust: %0d", mult_result_f - cf);
  end else
    $display("module arithmitec res=%0d, outw=%0d", multadd_result_w, doutw);
end
///////////////////////////////////

localparam ALIGN_BP = mult_result_f - cf;
localparam A_LAT = 4;
localparam B_LAT = A_LAT-1;
localparam C_LAT = A_LAT+1;

// Is the following still true?
// vivado synthesis comes back and says that this will most likely be implemented in registers
// because the abstract data type recognition is not supported. Registers are what I want and
// this is OK. But were I to change to `logic signed [X1_LAT-1:0][$bits(cx_t)-1:0] x1_delay;` I
// would then not be able to pull out the real and imaginary part with .re/.im struct notation.
a_data_t [A_LAT-1:0] ar_delay, ai_delay;
b_data_t [B_LAT-1:0] br_delay, bi_delay;
c_data_t [C_LAT-1:0] cr_delay, ci_delay;

logic signed [bw:0] add_re, add_im;
logic signed [aw:0] addcommon;

result_t m_reg_common, m_reg_common_d;
result_t common_im, common_re;
result_t m_reg_re, m_reg_im;  // register intermediate multiplication output

result_t c_re, c_im;

result_t cxmult_re, cxmult_im;
result_t multadd_re, multadd_im;
result_t multsub_re, multsub_im;

// generate common factor for 3 dsp slice implementation
always_ff @(posedge clk) begin
  if (rst) begin
    addcommon <= '0;
    m_reg_common <= '0;
    m_reg_common_d <= '0;
  end else begin
    addcommon <= ar_delay[0] - ai_delay[0];

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
  end else begin
    ar_delay <= {ar_delay[A_LAT-2:0], ar_in.data};
    br_delay <= {br_delay[B_LAT-2:0], br_in.data};
    cr_delay <= {cr_delay[C_LAT-2:0], cr_in.data};

    add_re <= br_delay[B_LAT-1] - bi_delay[B_LAT-1];

    m_reg_re <= ar_delay[A_LAT-1]*add_re;
    common_re <= m_reg_common_d;

    cxmult_re <= m_reg_re + common_re;
    c_re <= (cr_delay[C_LAT-1] <<< ALIGN_BP); // align binary point for addition

    multadd_re <= cxmult_re + c_re;
    multsub_re <= cxmult_re - c_re;
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

  end else begin
    ai_delay <= {ai_delay[A_LAT-2:0], ai_in.data};
    bi_delay <= {bi_delay[B_LAT-2:0], bi_in.data};
    ci_delay <= {ci_delay[C_LAT-2:0], ci_in.data};

    add_im <= bi_delay[B_LAT-1] + bi_delay[B_LAT-1];

    m_reg_im <= ai_delay[A_LAT-1]*add_im;
    common_im <= m_reg_common_d;

    cxmult_im <= m_reg_im + common_im;
    c_im <= (ci_delay[C_LAT-1] <<< ALIGN_BP); // align binary point for addition

    multadd_im <= cxmult_im + c_im;
    multsub_im <= cxmult_im - c_im;
  end
end

assign add_dout_re.data = multadd_re;
assign add_dout_im.data = multadd_im;
assign sub_dout_re.data = multsub_re;
assign sub_dout_im.data = multsub_im;


endmodule : alpaca_cx_multadd

/****************************************************
  test synth top
****************************************************/

module alpaca_cx_multadd_top (
  input wire logic clk,
  input wire logic rst,
  input wire sample_t ar, ai,
  input wire phase_t  br, bi,
  input wire sample_t cr, ci,

  output phase_mac_t add_re, add_im,
  output phase_mac_t sub_re, sub_im
);

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) ar_in(), ai_in(), cr_in(), ci_in();
fp_data #(.dtype(phase_t), .W(PHASE_WIDTH), .F(PHASE_FRAC_WIDTH)) br_in(), bi_in();
fp_data #(.dtype(phase_mac_t), .W(WIDTH+PHASE_WIDTH+1), .F(FRAC_WIDTH+PHASE_FRAC_WIDTH)) add_dout_re(), add_dout_im();
fp_data #(.dtype(phase_mac_t), .W(WIDTH+PHASE_WIDTH+1), .F(FRAC_WIDTH+PHASE_FRAC_WIDTH)) sub_dout_re(), sub_dout_im();

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


alpaca_cx_multadd DUT (.*);

endmodule : alpaca_cx_multadd_top

