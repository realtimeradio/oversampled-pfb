`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_sim_constants_pkg::*;
import alpaca_dtypes_pkg::*;

/******************
  TESTBENCH
******************/

parameter int DUT_LAT = 7; // mult=5, rnd=2
parameter int END = 20;

parameter real WL = (WIDTH+COEFF_WID)+1;          // result word len (growth due to multiplication and one add)
parameter real FWL = (FRAC_WIDTH+COEFF_FRAC_WID); // fractional length (bits right of decimal)
parameter real IWL = WL-FWL;                      // integer word length (bits left of decimal)
parameter real lsb_scale = 2**(-FWL);             // weight of a single fractional bit

module multadd_convrnd_tb();

logic clk, rst;

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) a_in(), c_in();
fp_data #(.dtype(coeff_t), .W(COEFF_WID), .F(COEFF_FRAC_WID)) b_in();
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) dout();

clk_generator #(.PERIOD(PERIOD)) clk_gen_int (.*);
alpaca_multadd_convrnd DUT (.*);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

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

function sample_t conv_rnd(input sample_t a, coeff_t b, sample_t c);
  /* a convergent rounding function implemented all the steps in software to test hardwre output */
  mac_t half_lsb, cc, carryin, cscale, mult, mac, rnd;
  sample_t res, out;
  string mac_fixfmt, samp_fixfmt, coeff_fixfmt;

  localparam int bits = $bits(mac_t);
  localparam int frac_wid = FRAC_WIDTH+COEFF_FRAC_WID;
  localparam int int_wid = bits-frac_wid;
  localparam int outf = FRAC_WIDTH;
  localparam int SHIFT_LEFT = (frac_wid - outf - 1);
  localparam int ALIGN_BP = frac_wid - FRAC_WIDTH;

  automatic logic [SHIFT_LEFT:0] pattern = '0;
  logic pattern_detect;
  
  mac_fixfmt = fixed_fmt(bits, frac_wid);
  samp_fixfmt = fixed_fmt(WIDTH, FRAC_WIDTH);
  coeff_fixfmt = fixed_fmt(COEFF_WID, COEFF_FRAC_WID);

  half_lsb = 1'b1 << SHIFT_LEFT;
  //cc = half_lsb - 1;
  //carryin = 1'b1;

  cscale = c <<< ALIGN_BP; // align c input with the same scaling
  mult = a*b;
  mac = mult + cscale;
  rnd = mac + half_lsb;

  pattern_detect = (rnd[SHIFT_LEFT:0] == pattern) ? 1'b1 : 1'b0;

  res = (rnd >>> ALIGN_BP); // scale by shifting out
  out = pattern_detect ? {res[WIDTH-1:1], 1'b0} : res;

  //$display("%s", mac_fixfmt);
  //$display("%s", samp_fixfmt);
  //$display("%s", coeff_fixfmt);

  //$display("%0d, %0d, %0d, %0d, %0d, %0d", bits, frac_wid, int_wid, outf, SHIFT_LEFT, ALIGN_BP);

  $display("CONV RND FUNC:");
  $display({"a  : ", disp_conv(a, WIDTH, FRAC_WIDTH)});
  $display({"b  : ", disp_conv(b, COEFF_WID, COEFF_FRAC_WID)});
  $display({"c  : ", disp_conv(c, WIDTH, FRAC_WIDTH)});
  $display({"c' : ", disp_conv(cscale, bits, frac_wid)});

  $display({"mul: ", disp_conv(mult, bits, frac_wid)});
  $display({"%smac: ", disp_conv(mac, bits, frac_wid), "%s"}, GRN, RST);
  $display({"lsb: ", disp_conv(half_lsb, bits, frac_wid)});
  $display({"rnd: ", disp_conv(rnd, bits, frac_wid)});
  $display("det: 0b%1b", pattern_detect);
  $display({"res: ", disp_conv(res, WIDTH, FRAC_WIDTH)});
  $display({"%sout: ", disp_conv(out, WIDTH, FRAC_WIDTH), "%s"}, GRN, RST);

  $display("*********\n");
  return out;

endfunction
    
int simcycles;
initial begin
  simcycles=0;
  forever @(posedge clk)
    simcycles += (1 & clk);// & ~rst;
end

// SV LRM 1800-2017 Section 16.10 pg. 413-415 show an example of local variables in assertions
// with a pipelined latency example somebody online mentioned that this is discouraged as
// asserts are meant to be passive, but I am not sure about that given how useful this
// capability
property chk_output;
  sample_t mac;
  @(posedge clk) disable iff (rst)
    (1, mac = conv_rnd(a_in.data, b_in.data, c_in.data)) ##DUT_LAT (mac==dout.data);
    //##DUT_LAT (conv_rnd($past(a_in.data, DUT_LAT), $past(b_in.data, DUT_LAT), $past(c_in.data, DUT_LAT))==dout.data);
endproperty : chk_output

// main initial block
initial begin
  int errors;
  sample_t start_val;

  start_val = 1;

  rst <= 1;
  a_in.data <= start_val; b_in.data <= start_val; c_in.data <= start_val;
  @(posedge clk);
  @(negedge clk); rst = 0;

  for (int i=0; i<DUT_LAT; i++) begin
    wait_cycles();
    assert property (chk_output) else begin
      errors++;
      $display("%sConv rnd check failed!%s", RED, RST);
    end
    $display("%sT=%4d: {observed: 0x%0X}%s", GRN, simcycles, dout.data, RST);

    @(negedge clk);
    a_in.data += 1; b_in.data+=1; c_in.data-=1;
  end

  for (int i=0; i < END; i++) begin
    wait_cycles();
    assert property (chk_output) else begin
      errors++;
       $display("%sConv rnd check failed!%s", RED, RST);
    end
    $display(dout.print_all());
    //$display(dout.asfixedbinary());
    
    @(negedge clk);
    a_in.data += 1; b_in.data+=1; c_in.data-=1;
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;

end

endmodule : multadd_convrnd_tb

