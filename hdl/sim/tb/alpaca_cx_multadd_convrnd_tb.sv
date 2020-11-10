`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_sim_constants_pkg::*;
import alpaca_dtypes_pkg::*;

/****************************************************
  TESTBENCH
****************************************************/

typedef struct {
  mac_t im;
  mac_t re;
} cx_t;

typedef struct {
  sample_t add_im;
  sample_t add_re;
  sample_t sub_im;
  sample_t sub_re;
} Xk_t;

function cx_t cx_mult(sample_t ar, ai, coeff_t br, bi);
  cx_t z;
  z.re = ar*br - ai*bi;
  z.im = ar*bi + ai*br;
  return z;
endfunction

/*************************************************/

parameter int DUT_LAT = 9; // mult=7, rnd=2
parameter int END = 40;

parameter real WL = (WIDTH+COEFF_WID)+1;          // result word len (growth due to multiplication and one add)
parameter real FWL = (FRAC_WIDTH+COEFF_FRAC_WID); // fractional length (bits right of decimal)
parameter real IWL = WL-FWL;                        // integer word length (bits left of decimal)
parameter real lsb_scale = 2**(-FWL);               // weight of a single fractional bit

module cx_multadd_convrnd_tb();

logic clk, rst;

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) ar_in(), ai_in(), cr_in(), ci_in();
fp_data #(.dtype(coeff_t), .W(COEFF_WID), .F(COEFF_FRAC_WID)) br_in(), bi_in();
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) add_dout_re(), add_dout_im();
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) sub_dout_re(), sub_dout_im();

clk_generator #(.PERIOD(PERIOD)) clk_gen_int (.*);
alpaca_cx_multadd_convrnd DUT (.*);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

int simcycles;
initial begin
  simcycles=0;
  forever @(posedge clk)
    simcycles += (1 & clk);// & ~rst;
end

function string fixed_fmt(input int width, frac);
  automatic int int_bits = width-frac;
  automatic string s;
  if (frac==0)
    s = $psprintf("%%%0d%0s.", int_bits, "b");
  else
    s = $psprintf({"%%%0d%0s",".","%%%0d%0s"}, int_bits, "b", frac, "b");

  return s;
endfunction

function string disp_conv(int v, w, f);
  string s;
  int mask;

  s = fixed_fmt(w, f);
  s = {s, "  fp: %f"};

  if (f==0)
    s = $psprintf(s, (v & (2**w-1)), $itor(v));
  else
    // if the string format only specified integer word bits we wouldn't have to mask on the
    // integer portion, shift by f
    s = $psprintf(s, (v & (2**w-1)) >> f, v & (2**f-1), $itor(v)*(1.0/2**f));

  return s;
endfunction

function Xk_t conv_rnd(input sample_t ar, ai, cr, ci, coeff_t br, bi);
  /* a convergent rounding function implemented all the steps in software to test hardwre output */
  mac_t half_lsb, cc, carryin, crscale, ciscale;
  cx_t mult, macadd, macsub, rndadd, rndsub;
  cx_t resadd, ressub;
  Xk_t out;

  string mac_fixfmt, samp_fixfmt, coeff_fixfmt;

  localparam int bits = $bits(mac_t);
  localparam int frac_wid = FRAC_WIDTH+COEFF_FRAC_WID;
  localparam int int_wid = bits-frac_wid;
  localparam int outf = FRAC_WIDTH;
  localparam int SHIFT_LEFT = (frac_wid - outf - 1);
  localparam int ALIGN_BP = frac_wid - FRAC_WIDTH;

  automatic logic [SHIFT_LEFT:0] pattern = '0;
  logic pd_add_re, pd_add_im, pd_sub_re, pd_sub_im;
  
  mac_fixfmt = fixed_fmt(bits, frac_wid);
  samp_fixfmt = fixed_fmt(WIDTH, FRAC_WIDTH);
  coeff_fixfmt = fixed_fmt(COEFF_WID, COEFF_FRAC_WID);

  half_lsb = 1'b1 << SHIFT_LEFT;
  //cc = half_lsb - 1;
  //carryin = 1'b1;

  crscale = cr <<< ALIGN_BP; // align cr input with the same scaling
  ciscale = ci <<< ALIGN_BP; // align ci input with the same scaling

  mult = cx_mult(ar, ai, br, bi);

  macadd.re = crscale + mult.re;
  macadd.im = ciscale + mult.im;
  macsub.re = crscale - mult.re;
  macsub.im = ciscale - mult.im;

  rndadd.re = macadd.re + half_lsb;
  rndadd.im = macadd.im + half_lsb;
  rndsub.re = macsub.re + half_lsb;
  rndsub.im = macsub.im + half_lsb;

  pd_add_re = (rndadd.re[SHIFT_LEFT:0] == pattern) ? 1'b1 : 1'b0;
  pd_add_im = (rndadd.im[SHIFT_LEFT:0] == pattern) ? 1'b1 : 1'b0;
  pd_sub_re = (rndsub.re[SHIFT_LEFT:0] == pattern) ? 1'b1 : 1'b0;
  pd_sub_im = (rndsub.im[SHIFT_LEFT:0] == pattern) ? 1'b1 : 1'b0;

  resadd.re = (rndadd.re >>> ALIGN_BP); // scale by shifting out
  resadd.im = (rndadd.im >>> ALIGN_BP); // scale by shifting out
  ressub.re = (rndsub.re >>> ALIGN_BP);
  ressub.im = (rndsub.im >>> ALIGN_BP);

  out.add_re = pd_add_re ? {resadd.re[WIDTH-1:1], 1'b0} : resadd.re;
  out.add_im = pd_add_im ? {resadd.im[WIDTH-1:1], 1'b0} : resadd.im;
  out.sub_re = pd_sub_re ? {ressub.re[WIDTH-1:1], 1'b0} : ressub.re;
  out.sub_im = pd_sub_im ? {ressub.im[WIDTH-1:1], 1'b0} : ressub.im;

  //$display("%s", mac_fixfmt);
  //$display("%s", samp_fixfmt);
  //$display("%s", coeff_fixfmt);

  //$display("%0d, %0d, %0d, %0d, %0d, %0d", bits, frac_wid, int_wid, outf, SHIFT_LEFT, ALIGN_BP);

  $display("CONV RND FUNC:");
  $display({"ar : ", disp_conv(ar, WIDTH, FRAC_WIDTH)});
  $display({"ai : ", disp_conv(ai, WIDTH, FRAC_WIDTH)});
  $display({"br : ", disp_conv(br, COEFF_WID, COEFF_FRAC_WID)});
  $display({"bi : ", disp_conv(bi, COEFF_WID, COEFF_FRAC_WID)});
  $display({"cr : ", disp_conv(cr, WIDTH, FRAC_WIDTH)});
  $display({"ci : ", disp_conv(ci, WIDTH, FRAC_WIDTH)});
  $display({"cr': ", disp_conv(crscale, bits, frac_wid)});
  $display({"ci': ", disp_conv(ciscale, bits, frac_wid)});

  $display({"mul.re: ", disp_conv(mult.re, bits, frac_wid)});
  $display({"mul.im: ", disp_conv(mult.im, bits, frac_wid)});
  $display({"%sadd.re: ", disp_conv(macadd.re, bits, frac_wid), "%s"}, GRN, RST);
  $display({"%sadd.im: ", disp_conv(macadd.im, bits, frac_wid), "%s"}, GRN, RST);
  $display({"%ssub.re: ", disp_conv(macsub.re, bits, frac_wid), "%s"}, GRN, RST);
  $display({"%ssub.im: ", disp_conv(macsub.im, bits, frac_wid), "%s"}, GRN, RST);
  $display({"lsb: ", disp_conv(half_lsb, bits, frac_wid)});
  $display({"rndadd.re: ", disp_conv(rndadd.re, bits, frac_wid)});
  $display({"rndadd.im: ", disp_conv(rndadd.im, bits, frac_wid)});
  $display({"rndsub.re: ", disp_conv(rndsub.re, bits, frac_wid)});
  $display({"rndsub.im: ", disp_conv(rndsub.im, bits, frac_wid)});
  $display("pd_add_re: 0b%1b", pd_add_re);
  $display("pd_add_im: 0b%1b", pd_add_im);
  $display("pd_sub_re: 0b%1b", pd_sub_re);
  $display("pd_sub_im: 0b%1b", pd_sub_im);
  $display({"resadd.re: ", disp_conv(resadd.re, WIDTH, FRAC_WIDTH)});
  $display({"resadd.im: ", disp_conv(resadd.im, WIDTH, FRAC_WIDTH)});
  $display({"ressub.re: ", disp_conv(ressub.re, WIDTH, FRAC_WIDTH)});
  $display({"ressub.im: ", disp_conv(ressub.im, WIDTH, FRAC_WIDTH)});
  $display({"%sout.addre: ", disp_conv(out.add_re, WIDTH, FRAC_WIDTH), "%s"}, GRN, RST);
  $display({"%sout.addim: ", disp_conv(out.add_im, WIDTH, FRAC_WIDTH), "%s"}, GRN, RST);
  $display({"%sout.subre: ", disp_conv(out.sub_re, WIDTH, FRAC_WIDTH), "%s"}, GRN, RST);
  $display({"%sout.subim: ", disp_conv(out.sub_im, WIDTH, FRAC_WIDTH), "%s"}, GRN, RST);

  $display("*********\n");
  return out;
endfunction

property chk_output;
  Xk_t Xk;
  @(posedge clk) disable iff (rst)
    (1, Xk = conv_rnd(ar_in.data, ai_in.data, cr_in.data, ci_in.data, br_in.data, bi_in.data))
    ##DUT_LAT
    (Xk.add_re == add_dout_re.data &&
     Xk.add_im == add_dout_im.data &&
     Xk.sub_re == sub_dout_re.data &&
     Xk.sub_im == sub_dout_im.data);
endproperty

// main initial block
initial begin
  int errors;
  sample_t start_val_re;
  sample_t start_val_im;

  Xk_t Xk;

  start_val_re = 1;
  start_val_im = 1;

  rst <= 1;
  ar_in.data <= start_val_re; br_in.data <= start_val_re; cr_in.data <= start_val_re;
  ai_in.data <= start_val_im; bi_in.data <= start_val_im; ci_in.data <= start_val_im;
  @(posedge clk);
  @(negedge clk); rst = 0;

  for (int i=0; i<DUT_LAT; i++) begin
    wait_cycles();
    assert property (chk_output) else begin
      errors++;
      $display("%sConv rnd check failed!%s", RED, RST);
    end
    $display("%sT=%4d: {observed: 0x%0X}%s", GRN, simcycles, add_dout_re.data, RST);

    @(negedge clk);
    ar_in.data += 1; br_in.data-=1; cr_in.data+=1;
    ai_in.data += 1; bi_in.data+=1; ci_in.data-=1;

  end

  for (int i=0; i < END; i++) begin
    wait_cycles();
    assert property (chk_output) else begin
      errors++;
       $display("%sConv rnd check failed!%s", RED, RST);
    end
    $display(add_dout_re.print_all());
    $display(add_dout_im.print_all());
    $display(sub_dout_re.print_all());
    $display(sub_dout_im.print_all());

    @(negedge clk);
    ar_in.data += 1; br_in.data-=1; cr_in.data+=1;
    ai_in.data += 1; bi_in.data+=1; ci_in.data-=1;

  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;

end

endmodule : cx_multadd_convrnd_tb


